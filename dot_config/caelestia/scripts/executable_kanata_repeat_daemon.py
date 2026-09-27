import asyncio
import evdev
from evdev import UInput, ecodes as e

# Proxy key → real key mapping.
# Kanata remaps arrows/bspc/del to these F-keys. We translate them back.
# XKB maps these F-keys to NoSymbol so apps never see them.
PROXY_MAP = {
    e.KEY_F18: e.KEY_UP,
    e.KEY_F19: e.KEY_DOWN,
    e.KEY_F20: e.KEY_LEFT,
    e.KEY_F21: e.KEY_RIGHT,
    e.KEY_F22: e.KEY_BACKSPACE,
    e.KEY_F24: e.KEY_DELETE,
}

KEY_F13 = e.KEY_F13
NORMAL_RATE = 100.0  # Hz (10ms between repeats)
SLOW_RATE = 20.0    # Hz (50ms between repeats)
DELAY = 0.35        # Seconds before repeat starts

class RepeatDaemon:
    def __init__(self):
        self.ui = UInput(name="caelestia-repeat-daemon")
        self.active_repeats = {}
        self.current_rate = NORMAL_RATE

    async def repeat_loop(self, target_code):
        """Emit rapid press+release cycles for a key."""
        try:
            await asyncio.sleep(DELAY)
            while True:
                interval = 1.0 / self.current_rate
                hold_time = interval * 0.7  # Hold key for 70% of cycle
                gap_time = interval * 0.3   # Release for 30%
                
                # Key is currently DOWN. Release it to start the repeat cycle.
                self.ui.write(e.EV_KEY, target_code, 0)
                self.ui.syn()
                await asyncio.sleep(gap_time)
                
                # Press it again
                self.ui.write(e.EV_KEY, target_code, 1)
                self.ui.syn()
                await asyncio.sleep(hold_time)
        except asyncio.CancelledError:
            # The physical release event handles the final cleanup
            pass

    def handle_event(self, event):
        if event.type != e.EV_KEY:
            return

        # F13 toggles speed (mid-flight!)
        if event.code == KEY_F13:
            if event.value == 1:
                self.current_rate = SLOW_RATE
            elif event.value == 0:
                self.current_rate = NORMAL_RATE
            return

        # Proxy keys → start/stop repeat loops
        if event.code in PROXY_MAP:
            target_code = PROXY_MAP[event.code]
            if event.value == 1:  # Down
                # Emit the physical DOWN event immediately
                self.ui.write(e.EV_KEY, target_code, 1)
                self.ui.syn()
                
                if event.code in self.active_repeats:
                    self.active_repeats[event.code].cancel()
                self.active_repeats[event.code] = asyncio.create_task(
                    self.repeat_loop(target_code)
                )
            elif event.value == 0:  # Up
                # Emit the physical UP event immediately
                self.ui.write(e.EV_KEY, target_code, 0)
                self.ui.syn()
                
                if event.code in self.active_repeats:
                    self.active_repeats[event.code].cancel()
                    del self.active_repeats[event.code]


async def read_device(dev, daemon):
    """Read events from a single kanata device. No grab — safe from lockouts."""
    try:
        async for event in dev.async_read_loop():
            daemon.handle_event(event)
    except Exception:
        pass  # Device disconnected


async def device_scanner(daemon):
    """Continuously scan for new kanata devices (handles hotplug/restart)."""
    active_paths = set()
    while True:
        try:
            current_paths = set()
            for path in evdev.list_devices():
                try:
                    dev = evdev.InputDevice(path)
                    current_paths.add(path)
                    if path not in active_paths and "kanata" in dev.name.lower():
                        asyncio.create_task(read_device(dev, daemon))
                except Exception:
                    pass
            active_paths = current_paths
        except Exception:
            pass
        await asyncio.sleep(5.0)  # Scan less frequently to reduce I/O overhead


async def main():
    loop = asyncio.get_running_loop()
    loop.set_exception_handler(lambda l, c: None)  # Suppress unhandled exceptions
    daemon = RepeatDaemon()
    await device_scanner(daemon)


if __name__ == "__main__":
    asyncio.run(main())
