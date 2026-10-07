from __future__ import annotations

import os
import queue
import re
import subprocess
import sys
import time
import threading
import webbrowser
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import messagebox, ttk

try:
    import psutil
except ImportError:
    root = tk.Tk()
    root.withdraw()
    messagebox.showerror(
        "Missing dependency",
        "The required package 'psutil' is not installed.\n\n"
        "Run builder.bat, or manually run:\n"
        "python -m pip install --user psutil",
    )
    raise SystemExit(1)


# =============================================================================
# Configuration
# =============================================================================
GITEA_ROOT = Path(r"C:\Gitea")
GITEA_EXE = GITEA_ROOT / "gitea.exe"
GITEA_START_ARGUMENTS = ["web"]
GITEA_WEB_URL = "http://localhost:3000"
GITEA_PORT = 3000

HARDWARE_REFRESH_MS = 1000
STORAGE_REFRESH_SECONDS = 30
CONNECTION_REFRESH_MS = 2000

# Dark Gitea-like theme
BG = "#071008"
PANEL = "#0f1a11"
PANEL_2 = "#132316"
BORDER = "#285335"
TEXT = "#e8f6ea"
MUTED = "#a9bdaa"
GREEN = "#5aa02c"
GREEN_BRIGHT = "#82dc5d"
GREEN_DARK = "#234c1e"
TREE_BG = "#0a140c"
TREE_SELECTED = "#285335"
DANGER = "#9b3030"
RUNNING_GREEN = "#38ff61"
STOPPED_RED = "#ff4040"
RUNNING_BADGE_BG = "#10391b"
STOPPED_BADGE_BG = "#3b1010"


def resource_path(relative: str) -> Path:
    base = getattr(sys, "_MEIPASS", None)
    if base:
        return Path(base) / relative
    return Path(__file__).resolve().parent / relative


ICON_ICO = resource_path("GiteaServerMonitor.ico")
ICON_PNG = resource_path("GiteaServerMonitor_icon.png")


def format_bytes(value: int | float) -> str:
    value = float(value)
    units = ("B", "KB", "MB", "GB", "TB", "PB")
    for unit in units:
        if abs(value) < 1024.0 or unit == units[-1]:
            return f"{value:,.2f} {unit}"
        value /= 1024.0
    return f"{value:,.2f} PB"


def format_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)

    if days:
        return f"{days}d {hours:02d}h {minutes:02d}m"
    if hours:
        return f"{hours}h {minutes:02d}m {secs:02d}s"
    return f"{minutes}m {secs:02d}s"


def normalized_path(path: str | Path) -> str:
    try:
        return os.path.normcase(os.path.abspath(str(path)))
    except OSError:
        return os.path.normcase(str(path))


def is_gitea_process(process: psutil.Process) -> bool:
    try:
        if (process.name() or "").lower() != "gitea.exe":
            return False
        try:
            exe = process.exe()
            if exe:
                return Path(exe).name.lower() == "gitea.exe"
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            pass
        return True
    except (psutil.AccessDenied, psutil.NoSuchProcess):
        return False


def find_all_gitea_processes() -> list[psutil.Process]:
    return [p for p in psutil.process_iter(["pid", "name", "exe", "create_time"]) if is_gitea_process(p)]


def find_primary_gitea_process() -> psutil.Process | None:
    processes = find_all_gitea_processes()
    if not processes:
        return None

    expected = normalized_path(GITEA_EXE)
    for process in processes:
        try:
            exe = process.exe()
            if exe and normalized_path(exe) == expected:
                return process
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            continue

    return processes[0]


def start_gitea_hidden() -> tuple[bool, str]:
    existing = find_all_gitea_processes()
    if existing:
        pids = ", ".join(str(p.pid) for p in existing)
        return True, f"Gitea is already running. Active PID(s): {pids}"

    if not GITEA_EXE.exists():
        return False, f"Gitea executable was not found at:\n{GITEA_EXE}"

    creation_flags = 0
    startup_info = None

    if os.name == "nt":
        creation_flags = (
            getattr(subprocess, "CREATE_NO_WINDOW", 0)
            | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
        )
        startup_info = subprocess.STARTUPINFO()
        startup_info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup_info.wShowWindow = subprocess.SW_HIDE

    try:
        subprocess.Popen(
            [str(GITEA_EXE), *GITEA_START_ARGUMENTS],
            cwd=str(GITEA_ROOT),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=creation_flags,
            startupinfo=startup_info,
            close_fds=True,
        )
    except OSError as exc:
        return False, f"Windows could not start Gitea:\n{exc}"

    for _ in range(30):
        time.sleep(0.1)
        processes = find_all_gitea_processes()
        if processes:
            pids = ", ".join(str(p.pid) for p in processes)
            return True, f"Gitea started in the background. Active PID(s): {pids}"

    return True, "Gitea was launched, but its process has not appeared yet."


class StorageSnapshot:
    def __init__(
        self,
        root: Path,
        totals: dict[Path, tuple[int, int]],
        children: dict[Path, list[Path]],
        errors: int,
        elapsed: float,
    ) -> None:
        self.root = root
        self.totals = totals
        self.children = children
        self.errors = errors
        self.elapsed = elapsed


def scan_storage(root: Path) -> StorageSnapshot:
    started = time.monotonic()
    totals: dict[Path, tuple[int, int]] = {}
    children: dict[Path, list[Path]] = {}
    own_values: dict[Path, tuple[int, int]] = {}
    errors = 0

    stack: list[tuple[Path, bool]] = [(root, False)]

    while stack:
        directory, visited = stack.pop()

        if visited:
            own_size, own_files = own_values.get(directory, (0, 0))
            total_size = own_size
            total_files = own_files

            for child in children.get(directory, []):
                child_size, child_files = totals.get(child, (0, 0))
                total_size += child_size
                total_files += child_files

            totals[directory] = (total_size, total_files)
            continue

        stack.append((directory, True))
        child_dirs: list[Path] = []
        own_size = 0
        own_files = 0

        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    try:
                        if entry.is_symlink():
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            child = Path(entry.path)
                            child_dirs.append(child)
                            stack.append((child, False))
                        elif entry.is_file(follow_symlinks=False):
                            own_size += entry.stat(follow_symlinks=False).st_size
                            own_files += 1
                    except (OSError, PermissionError):
                        errors += 1
        except (OSError, PermissionError):
            errors += 1

        child_dirs.sort(key=lambda p: p.name.lower())
        children[directory] = child_dirs
        own_values[directory] = (own_size, own_files)

    return StorageSnapshot(root, totals, children, errors, time.monotonic() - started)


class ConnectionTracker:
    def __init__(self, port: int) -> None:
        self.port = port

        # Session-only tracking. This resets every time the monitor app starts.
        self.session_ips: dict[str, dict[str, object]] = {}
        self.events: list[str] = []
        self.log_offsets: dict[Path, int] = {}

    def _add_new_ip(self, ip: str, source: str) -> None:
        now = datetime.now()

        if ip not in self.session_ips:
            self.session_ips[ip] = {
                "first": now,
                "last": now,
                "count": 1,
                "source": source,
            }
            self.events.append(f"[{now:%I:%M:%S %p}] New IP this session: {ip} ({source})")
            self.events = self.events[-300:]
        else:
            stat = self.session_ips[ip]
            stat["last"] = now
            stat["count"] = int(stat.get("count", 0)) + 1
            stat["source"] = source

    def poll_active_connections(self) -> list[tuple[str, str, str, str, str]]:
        """
        Watch current TCP connections to the Gitea port.

        The UI only logs a new IP once per monitor start/session.
        Repeated connections from the same IP update the count but do not add
        repeated log lines.
        """
        active_rows: list[tuple[str, str, str, str, str]] = []

        try:
            connections = psutil.net_connections(kind="tcp")
        except (psutil.AccessDenied, OSError):
            return active_rows

        for conn in connections:
            try:
                if not conn.laddr or conn.laddr.port != self.port:
                    continue
                if not conn.raddr:
                    continue

                ip = conn.raddr.ip
                remote_port = int(conn.raddr.port)
                status = conn.status or "UNKNOWN"

                self._add_new_ip(ip, "Active TCP connection")

                stat = self.session_ips.get(ip, {})
                first = stat.get("first")
                count = stat.get("count", 1)
                first_seen = first.strftime("%I:%M:%S %p") if hasattr(first, "strftime") else ""

                active_rows.append(
                    (
                        ip,
                        str(remote_port),
                        status,
                        str(count),
                        first_seen,
                    )
                )
            except Exception:
                continue

        return active_rows

    def poll_gitea_logs(self) -> None:
        """
        Best-effort appended-log parsing.

        This starts near the end of each log file when the monitor opens, so it
        does not dump old historical IPs. It only records IPs that appear in new
        log lines during the current monitor session.
        """
        log_dirs = [
            GITEA_ROOT / "log",
            GITEA_ROOT / "logs",
            GITEA_ROOT,
        ]

        candidates: list[Path] = []
        for folder in log_dirs:
            if not folder.exists() or not folder.is_dir():
                continue
            try:
                candidates.extend(folder.glob("*.log"))
            except OSError:
                continue

        ip_regex = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")

        for log_file in candidates[:25]:
            try:
                size = log_file.stat().st_size

                if log_file not in self.log_offsets:
                    # Start at the current end of the file. This makes the log
                    # session-only instead of showing old historical addresses.
                    self.log_offsets[log_file] = size

                offset = self.log_offsets.get(log_file, 0)
                if size < offset:
                    offset = 0

                with log_file.open("r", encoding="utf-8", errors="ignore") as fh:
                    fh.seek(offset)
                    lines = fh.readlines()
                    self.log_offsets[log_file] = fh.tell()

                for line in lines[-200:]:
                    for ip in ip_regex.findall(line):
                        self._add_new_ip(ip, f"Log: {log_file.name}")
            except OSError:
                continue

    def get_unique_ip_rows(self) -> list[tuple[str, str, str, str]]:
        rows: list[tuple[str, str, str, str]] = []

        for ip, stat in self.session_ips.items():
            first = stat.get("first")
            last = stat.get("last")
            count = stat.get("count", 0)
            source = str(stat.get("source", ""))

            first_text = first.strftime("%I:%M:%S %p") if hasattr(first, "strftime") else ""
            last_text = last.strftime("%I:%M:%S %p") if hasattr(last, "strftime") else ""

            rows.append((ip, first_text, last_text, str(count), source))

        rows.sort(key=lambda row: row[1])
        return rows


class AppButton(tk.Canvas):
    def __init__(self, master, text: str, command=None, danger: bool = False, **kwargs):
        self.text = text
        self.command = command
        self.danger = danger
        self.radius = kwargs.pop("radius", 13)
        self.padx = kwargs.pop("padx", 18)
        self.pady = kwargs.pop("pady", 9)
        self.font = kwargs.pop("font", ("Segoe UI", 10, "bold"))

        self.bg_normal = "#632222" if danger else "#1f5a26"
        self.bg_hover = DANGER if danger else "#2f8a32"
        self.bg_pressed = "#401616" if danger else "#16411b"
        self.fg = "#ffffff"

        temp = tk.Label(master, text=text, font=self.font)
        temp.update_idletasks()
        width = max(92, temp.winfo_reqwidth() + self.padx * 2)
        height = max(36, temp.winfo_reqheight() + self.pady * 2)
        temp.destroy()

        super().__init__(
            master,
            width=width,
            height=height,
            bg=master.cget("bg") if hasattr(master, "cget") else BG,
            highlightthickness=0,
            bd=0,
            cursor="hand2",
            **kwargs,
        )

        self._draw(self.bg_normal)
        self.bind("<Enter>", lambda _e: self._draw(self.bg_hover))
        self.bind("<Leave>", lambda _e: self._draw(self.bg_normal))
        self.bind("<ButtonPress-1>", lambda _e: self._draw(self.bg_pressed))
        self.bind("<ButtonRelease-1>", self._release)

    def _rounded_rect(self, x1, y1, x2, y2, r, **kwargs):
        points = [
            x1+r, y1, x2-r, y1, x2, y1, x2, y1+r,
            x2, y2-r, x2, y2, x2-r, y2, x1+r, y2,
            x1, y2, x1, y2-r, x1, y1+r, x1, y1,
        ]
        return self.create_polygon(points, smooth=True, **kwargs)

    def _draw(self, fill: str):
        self.delete("all")
        w = int(self["width"])
        h = int(self["height"])
        self._rounded_rect(2, 2, w-2, h-2, self.radius, fill=fill, outline="")
        self.create_text(
            w // 2,
            h // 2,
            text=self.text,
            fill=self.fg,
            font=self.font,
        )

    def _release(self, _event):
        self._draw(self.bg_hover)
        if callable(self.command):
            self.command()


class MetricCard(tk.Frame):
    def __init__(self, master, title: str, variable: tk.StringVar):
        super().__init__(
            master,
            bg=PANEL,
            highlightthickness=1,
            highlightbackground=BORDER,
            padx=10,
            pady=10,
        )

        tk.Label(
            self,
            text=title,
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="center")

        tk.Label(
            self,
            textvariable=variable,
            bg=PANEL,
            fg=GREEN_BRIGHT,
            font=("Segoe UI", 13, "bold"),
            justify="center",
        ).pack(anchor="center", pady=(3, 0))


class GiteaMonitor(tk.Tk):
    def __init__(self, startup_message: str) -> None:
        super().__init__()

        self.title("Gitea Server Monitor")
        self.geometry("1260x820")
        self.minsize(980, 650)
        self.configure(bg=BG)

        try:
            if ICON_ICO.exists():
                self.iconbitmap(str(ICON_ICO))
        except Exception:
            pass

        self.primary_process: psutil.Process | None = None
        self.last_io_read: int | None = None
        self.last_io_write: int | None = None
        self.last_io_time: float | None = None

        self.storage_queue: queue.Queue[StorageSnapshot | Exception] = queue.Queue()
        self.storage_scan_running = False
        self.last_storage_scan = 0.0

        self.connection_tracker = ConnectionTracker(GITEA_PORT)

        self.status_var = tk.StringVar(value=startup_message)
        self.server_state_var = tk.StringVar(value="CHECKING")
        self.instances_var = tk.StringVar(value="--")
        self.server_cpu_var = tk.StringVar(value="--")
        self.server_ram_var = tk.StringVar(value="--")
        self.gitea_cpu_var = tk.StringVar(value="--")
        self.gitea_ram_var = tk.StringVar(value="--")
        self.gitea_io_var = tk.StringVar(value="--")
        self.gitea_uptime_var = tk.StringVar(value="--")
        self.drive_free_var = tk.StringVar(value="--")
        self.storage_total_var = tk.StringVar(value="Calculating...")
        self.storage_detail_var = tk.StringVar(value="Scanning C:\\Gitea...")
        self.connection_summary_var = tk.StringVar(value="Watching port 3000...")

        self.header_icon_img = None

        self._configure_styles()
        self._build_ui()

        psutil.cpu_percent(interval=None)
        self.refresh_storage()
        self.after(200, self._poll_storage_queue)
        self.after(100, self._update_hardware)
        self.after(500, self._update_connections)

    def _configure_styles(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        style.configure(
            "Dark.Treeview",
            background=TREE_BG,
            foreground=TEXT,
            fieldbackground=TREE_BG,
            bordercolor=BORDER,
            rowheight=25,
            font=("Segoe UI", 9),
        )
        style.map(
            "Dark.Treeview",
            background=[("selected", TREE_SELECTED)],
            foreground=[("selected", "#ffffff")],
        )
        style.configure(
            "Dark.Treeview.Heading",
            background=GREEN_DARK,
            foreground="#ffffff",
            relief="flat",
            font=("Segoe UI", 9, "bold"),
        )
        style.map("Dark.Treeview.Heading", background=[("active", GREEN)])

    def _build_ui(self) -> None:
        outer = tk.Frame(self, bg=BG)
        outer.pack(fill="both", expand=True, padx=16, pady=16)

        header = tk.Frame(outer, bg=BG)
        header.pack(fill="x")

        try:
            if ICON_PNG.exists():
                raw_img = tk.PhotoImage(file=str(ICON_PNG))
                # Uploaded icon is large; shrink for header without requiring Pillow at runtime.
                factor = max(1, int(max(raw_img.width(), raw_img.height()) / 56))
                self.header_icon_img = raw_img.subsample(factor, factor)
                tk.Label(header, image=self.header_icon_img, bg=BG).pack(side="left", padx=(0, 12))
        except Exception:
            self.header_icon_img = None

        title_box = tk.Frame(header, bg=BG)
        title_box.pack(side="left", fill="x", expand=True)

        tk.Label(
            title_box,
            text="Gitea Server Monitor",
            bg=BG,
            fg=TEXT,
            font=("Segoe UI", 22, "bold"),
        ).pack(anchor="w")

        tk.Label(
            title_box,
            text="Manual start/stop, live usage, storage, and IP activity",
            bg=BG,
            fg=MUTED,
            font=("Segoe UI", 10),
        ).pack(anchor="w")

        actions = tk.Frame(header, bg=BG)
        actions.pack(side="right")

        AppButton(actions, text="Open Web UI", command=lambda: webbrowser.open(GITEA_WEB_URL)).pack(side="left", padx=(0, 8))
        AppButton(actions, text="Open C:\\Gitea", command=self.open_gitea_folder).pack(side="left", padx=(0, 8))
        AppButton(actions, text="Start Gitea", command=self.start_gitea_from_button).pack(side="left", padx=(0, 8))
        AppButton(actions, text="Kill All", danger=True, command=self.kill_all_gitea_instances).pack(side="left")

        status = tk.Frame(outer, bg=PANEL, highlightthickness=1, highlightbackground=BORDER)
        status.pack(fill="x", pady=(16, 12))

        status_top = tk.Frame(status, bg=PANEL)
        status_top.pack(fill="x", padx=12, pady=(10, 4))

        self.status_badge = tk.Label(
            status_top,
            textvariable=self.server_state_var,
            bg=STOPPED_BADGE_BG,
            fg=STOPPED_RED,
            font=("Segoe UI", 13, "bold"),
            padx=16,
            pady=7,
        )
        self.status_badge.pack(side="left", padx=(0, 12))

        tk.Label(
            status_top,
            textvariable=self.status_var,
            bg=PANEL,
            fg=TEXT,
            font=("Segoe UI", 10, "bold"),
        ).pack(side="left", fill="x", expand=True)

        tk.Label(
            status,
            textvariable=self.instances_var,
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="w", padx=12, pady=(0, 10))

        metrics = tk.Frame(outer, bg=BG)
        metrics.pack(fill="x", pady=(0, 12))

        metric_items = [
            ("Server CPU", self.server_cpu_var),
            ("Server RAM", self.server_ram_var),
            ("Gitea CPU", self.gitea_cpu_var),
            ("Gitea RAM", self.gitea_ram_var),
            ("Gitea Disk I/O", self.gitea_io_var),
            ("Gitea Uptime", self.gitea_uptime_var),
            ("C: Free", self.drive_free_var),
        ]

        for i, (title, var) in enumerate(metric_items):
            metrics.columnconfigure(i, weight=1)
            MetricCard(metrics, title, var).grid(
                row=0,
                column=i,
                sticky="nsew",
                padx=(0 if i == 0 else 6, 0),
            )

        split = tk.PanedWindow(
            outer,
            orient=tk.HORIZONTAL,
            bg=BG,
            sashwidth=7,
            sashrelief="flat",
            bd=0,
            opaqueresize=True,
        )
        split.pack(fill="both", expand=True)

        left = tk.Frame(split, bg=PANEL, highlightthickness=1, highlightbackground=BORDER)
        right = tk.Frame(split, bg=PANEL, highlightthickness=1, highlightbackground=BORDER)
        split.add(left, minsize=520, stretch="always")
        split.add(right, minsize=410, stretch="always")

        self._build_storage_panel(left)
        self._build_connections_panel(right)

    def _section_title(self, master, text: str) -> None:
        tk.Label(
            master,
            text=text,
            bg=PANEL,
            fg=TEXT,
            font=("Segoe UI", 13, "bold"),
        ).pack(side="left")

    def _build_storage_panel(self, parent: tk.Frame) -> None:
        header = tk.Frame(parent, bg=PANEL)
        header.pack(fill="x", padx=12, pady=(10, 8))

        self._section_title(header, "C:\\Gitea Storage")
        AppButton(header, text="Refresh", command=self.refresh_storage).pack(side="right")

        tk.Label(
            parent,
            textvariable=self.storage_total_var,
            bg=PANEL,
            fg=GREEN_BRIGHT,
            font=("Segoe UI", 10, "bold"),
        ).pack(anchor="w", padx=12)

        tk.Label(
            parent,
            textvariable=self.storage_detail_var,
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="w", padx=12, pady=(2, 8))

        frame = tk.Frame(parent, bg=PANEL)
        frame.pack(fill="both", expand=True, padx=12, pady=(0, 12))

        self.storage_tree = ttk.Treeview(
            frame,
            columns=("size", "files"),
            show="tree headings",
            style="Dark.Treeview",
            selectmode="browse",
        )
        self.storage_tree.heading("#0", text="Directory")
        self.storage_tree.heading("size", text="Size")
        self.storage_tree.heading("files", text="Files")
        self.storage_tree.column("#0", width=390, minwidth=250, stretch=True)
        self.storage_tree.column("size", width=125, anchor="e", stretch=False)
        self.storage_tree.column("files", width=90, anchor="e", stretch=False)

        yscroll = ttk.Scrollbar(frame, orient="vertical", command=self.storage_tree.yview)
        xscroll = ttk.Scrollbar(frame, orient="horizontal", command=self.storage_tree.xview)
        self.storage_tree.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)

        self.storage_tree.grid(row=0, column=0, sticky="nsew")
        yscroll.grid(row=0, column=1, sticky="ns")
        xscroll.grid(row=1, column=0, sticky="ew")
        frame.rowconfigure(0, weight=1)
        frame.columnconfigure(0, weight=1)

    def _build_connections_panel(self, parent: tk.Frame) -> None:
        header = tk.Frame(parent, bg=PANEL)
        header.pack(fill="x", padx=12, pady=(10, 8))

        self._section_title(header, "Connection / IP Activity")

        tk.Label(
            parent,
            textvariable=self.connection_summary_var,
            bg=PANEL,
            fg=GREEN_BRIGHT,
            font=("Segoe UI", 10, "bold"),
        ).pack(anchor="w", padx=12, pady=(0, 8))

        tk.Label(
            parent,
            text="Unique IPs that accessed Gitea during this monitor session",
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="w", padx=12)

        active_frame = tk.Frame(parent, bg=PANEL)
        active_frame.pack(fill="x", padx=12, pady=(4, 12))

        self.active_tree = ttk.Treeview(
            active_frame,
            columns=("ip", "first", "last", "count", "source"),
            show="headings",
            height=8,
            style="Dark.Treeview",
        )
        for col, title, width in [
            ("ip", "IP Address", 145),
            ("first", "First Seen", 95),
            ("last", "Last Seen", 95),
            ("count", "Hits", 60),
            ("source", "Source", 145),
        ]:
            self.active_tree.heading(col, text=title)
            self.active_tree.column(col, width=width, anchor="w", stretch=True)

        active_scroll = ttk.Scrollbar(active_frame, orient="vertical", command=self.active_tree.yview)
        self.active_tree.configure(yscrollcommand=active_scroll.set)
        self.active_tree.grid(row=0, column=0, sticky="nsew")
        active_scroll.grid(row=0, column=1, sticky="ns")
        active_frame.columnconfigure(0, weight=1)

        tk.Label(
            parent,
            text="Recent IP activity log",
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="w", padx=12)

        log_frame = tk.Frame(parent, bg=PANEL)
        log_frame.pack(fill="both", expand=True, padx=12, pady=(4, 12))

        self.connection_log = tk.Text(
            log_frame,
            bg=TREE_BG,
            fg=TEXT,
            insertbackground=GREEN_BRIGHT,
            selectbackground=TREE_SELECTED,
            relief="flat",
            bd=0,
            wrap="word",
            font=("Consolas", 9),
        )
        log_scroll = ttk.Scrollbar(log_frame, orient="vertical", command=self.connection_log.yview)
        self.connection_log.configure(yscrollcommand=log_scroll.set)

        self.connection_log.grid(row=0, column=0, sticky="nsew")
        log_scroll.grid(row=0, column=1, sticky="ns")
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

        self.connection_log.insert(
            "end",
            "Waiting for IP activity on port 3000...\n\n"
            "This panel watches active TCP connections and attempts to read new IPs from C:\\Gitea log files.\n",
        )
        self.connection_log.configure(state="disabled")

    def _set_server_state(self, running: bool) -> None:
        if running:
            self.server_state_var.set("RUNNING")
            self.status_badge.configure(bg=RUNNING_BADGE_BG, fg=RUNNING_GREEN)
        else:
            self.server_state_var.set("STOPPED")
            self.status_badge.configure(bg=STOPPED_BADGE_BG, fg=STOPPED_RED)

    def open_gitea_folder(self) -> None:
        if GITEA_ROOT.exists():
            try:
                os.startfile(GITEA_ROOT)
            except Exception as exc:
                messagebox.showerror("Could not open folder", str(exc))
        else:
            messagebox.showerror("Folder not found", f"{GITEA_ROOT} does not exist.")

    def start_gitea_from_button(self) -> None:
        success, message = start_gitea_hidden()
        self.status_var.set(message)
        if not success:
            messagebox.showerror("Could not start Gitea", message)

    def kill_all_gitea_instances(self) -> None:
        processes = find_all_gitea_processes()
        if not processes:
            messagebox.showinfo("No Gitea instances", "No running gitea.exe processes were found.")
            return

        details = []
        for process in processes:
            try:
                exe = process.exe()
            except (psutil.AccessDenied, psutil.NoSuchProcess):
                exe = "Path unavailable"
            details.append(f"PID {process.pid} — {exe}")

        confirmed = messagebox.askyesno(
            "Kill all Gitea instances?",
            "This will stop every running gitea.exe process.\n\n"
            + "\n".join(details)
            + "\n\nAny active Git operations or web requests will be interrupted. Continue?",
            icon="warning",
        )
        if not confirmed:
            return

        terminated = []
        failed = []

        for process in processes:
            try:
                process.terminate()
                terminated.append(process)
            except psutil.NoSuchProcess:
                continue
            except (psutil.AccessDenied, OSError) as exc:
                failed.append((process.pid, str(exc)))

        _, still_alive = psutil.wait_procs(terminated, timeout=4)

        for process in still_alive:
            try:
                process.kill()
            except psutil.NoSuchProcess:
                continue
            except (psutil.AccessDenied, OSError) as exc:
                failed.append((process.pid, str(exc)))

        if still_alive:
            psutil.wait_procs(still_alive, timeout=3)

        remaining = find_all_gitea_processes()
        self.primary_process = None
        self.last_io_read = None
        self.last_io_write = None
        self.last_io_time = None

        if remaining or failed:
            messages = []
            if remaining:
                messages.append("Still running PID(s): " + ", ".join(str(p.pid) for p in remaining))
            if failed:
                messages.append("Access/error details:\n" + "\n".join(f"PID {pid}: {error}" for pid, error in failed))

            self.status_var.set("Some Gitea instances could not be stopped.")
            messagebox.showwarning(
                "Gitea stop incomplete",
                "\n\n".join(messages) + "\n\nTry running the monitor as Administrator.",
            )
        else:
            self.status_var.set("All Gitea instances were stopped.")
            messagebox.showinfo("Gitea stopped", "All running Gitea instances were stopped successfully.")

    def _get_primary_process(self) -> psutil.Process | None:
        if self.primary_process is not None:
            try:
                if self.primary_process.is_running():
                    return self.primary_process
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        self.primary_process = find_primary_gitea_process()
        self.last_io_read = None
        self.last_io_write = None
        self.last_io_time = None

        if self.primary_process is not None:
            try:
                self.primary_process.cpu_percent(interval=None)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                self.primary_process = None

        return self.primary_process

    def _update_hardware(self) -> None:
        try:
            cpu = psutil.cpu_percent(interval=None)
            memory = psutil.virtual_memory()

            self.server_cpu_var.set(f"{cpu:.1f}%")
            self.server_ram_var.set(f"{memory.percent:.1f}%\n{format_bytes(memory.used)} / {format_bytes(memory.total)}")

            try:
                drive = psutil.disk_usage("C:\\")
                self.drive_free_var.set(f"{format_bytes(drive.free)}\n{100.0 - drive.percent:.1f}% free")
            except OSError:
                self.drive_free_var.set("Unavailable")

            all_processes = find_all_gitea_processes()
            if not all_processes:
                self.instances_var.set("Running instances: 0")
                self._set_server_state(False)
                self.status_var.set("Gitea server is stopped.")
                self.gitea_cpu_var.set("--")
                self.gitea_ram_var.set("--")
                self.gitea_io_var.set("--")
                self.gitea_uptime_var.set("--")
                self.primary_process = None
            else:
                pids = ", ".join(str(p.pid) for p in all_processes)
                self.instances_var.set(f"Running instances: {len(all_processes)} | PID(s): {pids}")

                process = self._get_primary_process()
                if process is not None:
                    try:
                        process_cpu = process.cpu_percent(interval=None)
                        process_memory = process.memory_info().rss
                        self.gitea_cpu_var.set(f"{process_cpu:.1f}%")
                        self.gitea_ram_var.set(format_bytes(process_memory))
                        self.gitea_uptime_var.set(format_duration(time.time() - process.create_time()))
                        self._set_server_state(True)
                        self.status_var.set(f"Gitea server is running. Primary PID: {process.pid}")

                        try:
                            io = process.io_counters()
                            now = time.monotonic()

                            if self.last_io_time is not None and self.last_io_read is not None and self.last_io_write is not None:
                                elapsed = max(now - self.last_io_time, 0.001)
                                read_rate = max(io.read_bytes - self.last_io_read, 0) / elapsed
                                write_rate = max(io.write_bytes - self.last_io_write, 0) / elapsed
                                self.gitea_io_var.set(f"R {format_bytes(read_rate)}/s\nW {format_bytes(write_rate)}/s")
                            else:
                                self.gitea_io_var.set("Measuring...")

                            self.last_io_read = io.read_bytes
                            self.last_io_write = io.write_bytes
                            self.last_io_time = now
                        except (psutil.AccessDenied, AttributeError):
                            self.gitea_io_var.set("Unavailable")
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        self.primary_process = None

            if not self.storage_scan_running and time.monotonic() - self.last_storage_scan >= STORAGE_REFRESH_SECONDS:
                self.refresh_storage()
        finally:
            self.after(HARDWARE_REFRESH_MS, self._update_hardware)

    def refresh_storage(self) -> None:
        if self.storage_scan_running:
            return

        if not GITEA_ROOT.exists():
            self.storage_total_var.set("C:\\Gitea was not found.")
            self.storage_detail_var.set("")
            return

        self.storage_scan_running = True
        self.storage_detail_var.set("Scanning folders...")

        def worker() -> None:
            try:
                self.storage_queue.put(scan_storage(GITEA_ROOT))
            except Exception as exc:
                self.storage_queue.put(exc)

        threading.Thread(target=worker, daemon=True).start()

    def _poll_storage_queue(self) -> None:
        try:
            result = self.storage_queue.get_nowait()
        except queue.Empty:
            self.after(200, self._poll_storage_queue)
            return

        self.storage_scan_running = False
        self.last_storage_scan = time.monotonic()

        if isinstance(result, Exception):
            self.storage_total_var.set("Storage scan failed.")
            self.storage_detail_var.set(str(result))
        else:
            self._display_storage(result)

        self.after(200, self._poll_storage_queue)

    def _display_storage(self, snapshot: StorageSnapshot) -> None:
        self.storage_tree.delete(*self.storage_tree.get_children())

        root_size, root_files = snapshot.totals.get(snapshot.root, (0, 0))
        root_id = self.storage_tree.insert(
            "",
            "end",
            text=str(snapshot.root),
            values=(format_bytes(root_size), f"{root_files:,}"),
            open=True,
        )

        def add_children(parent_item: str, directory: Path) -> None:
            for child in snapshot.children.get(directory, []):
                size, files = snapshot.totals.get(child, (0, 0))
                child_id = self.storage_tree.insert(
                    parent_item,
                    "end",
                    text=child.name,
                    values=(format_bytes(size), f"{files:,}"),
                    open=False,
                )
                add_children(child_id, child)

        add_children(root_id, snapshot.root)

        self.storage_total_var.set(f"Total: {format_bytes(root_size)} across {root_files:,} files")
        detail = f"Last scan: {datetime.now():%I:%M:%S %p} ({snapshot.elapsed:.1f}s)"
        if snapshot.errors:
            detail += f" | Skipped items: {snapshot.errors:,}"
        self.storage_detail_var.set(detail)

    def _update_connections(self) -> None:
        try:
            self.connection_tracker.poll_active_connections()
            self.connection_tracker.poll_gitea_logs()

            unique_rows = self.connection_tracker.get_unique_ip_rows()

            self.active_tree.delete(*self.active_tree.get_children())
            for row in unique_rows:
                self.active_tree.insert("", "end", values=row)

            self.connection_summary_var.set(
                f"Unique IPs this session: {len(unique_rows)}"
            )

            self.connection_log.configure(state="normal")
            self.connection_log.delete("1.0", "end")

            if self.connection_tracker.events:
                for line in self.connection_tracker.events[-160:]:
                    self.connection_log.insert("end", line + "\n")
            else:
                self.connection_log.insert(
                    "end",
                    "Waiting for the first new IP this session...\n\n"
                    "Only unique IP addresses are listed. Repeated access from the same IP updates Hits/Last Seen instead of adding duplicate log lines.\n"
                    "The app watches active TCP connections to port 3000 and also checks new lines in C:\\Gitea log files.\n",
                )

            self.connection_log.see("end")
            self.connection_log.configure(state="disabled")
        finally:
            self.after(CONNECTION_REFRESH_MS, self._update_connections)


def main() -> None:
    process = find_primary_gitea_process()
    if process is None:
        startup_message = "Gitea server is stopped. Click Start Gitea to run it."
    else:
        startup_message = f"Gitea server is already running. Primary PID: {process.pid}"

    app = GiteaMonitor(startup_message)
    app.mainloop()


if __name__ == "__main__":
    main()
