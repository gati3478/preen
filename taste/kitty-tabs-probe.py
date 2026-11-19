# What the tab bar drawer draws, as JSON, for pref-check's `kittytabs` reader:
# argv's last word is the drawer, and the kitty.conf beside it supplies the
# colours and the bell's symbol. Run only as `kitty +runpy`, which execs
# Python in-process and opens no window. No kitty is running here, so the
# drawer's lookups of live tabs are answered by the fixture below: tab 1 is
# active and its shell reported `alpha` while a helper runs elsewhere, tab 2
# is at home and has rung its bell, tab 3 is behind ssh and reports a program
# status of `S`, and tab 4 has reported nothing.
import json
import os
import runpy
import sys

from kitty.config import load_config
from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData

DRAWER = sys.argv[-1]
HOME = os.path.expanduser('~')
# per tab: what the shell reported, the oldest foreground process's directory,
# and whether the tab is behind ssh
WINDOWS = (
    ('file://probe/srv/alpha', '/srv/helper', False),
    ('file://probe' + HOME, HOME, False),
    ('file://remote/srv/elsewhere', '/srv/gamma', True),
    ('', '/srv/delta', False),
)
STATUS = {3: 'S  '}
OS_WINDOW = 1
BAR_COLUMNS = 30
ROW_COLUMNS = 60
CARD_ROWS = 3


class Child:
    def get_pid_for_cwd(self, oldest=False):
        return None


class Reported:
    def __init__(self, url):
        self.last_reported_cwd = url


class Window:
    child = Child()

    def __init__(self, reported, oldest, remote):
        self.screen, self.oldest, self.child_is_remote = Reported(reported), oldest, remote

    def get_cwd_of_child(self, oldest=False):
        return self.oldest if oldest else '/srv/newest'


class Tab:
    title = 'shell'

    def __init__(self, tab_id):
        self.id = tab_id
        self.active_window = Window(*WINDOWS[(tab_id - 1) % len(WINDOWS)])


class Manager:
    def __init__(self, count):
        self.tabs = [Tab(n + 1) for n in range(count)]


class Boss:
    def __init__(self, count):
        self.manager = Manager(count)
        self.os_window_map = {OS_WINDOW: self.manager}

    def tab_for_id(self, tab_id):
        return self.manager.tabs[tab_id - 1]


class Accessor:
    def __init__(self, tab_id):
        self.program_status = STATUS.get(tab_id, '')


draw_tab = runpy.run_path(DRAWER)['draw_tab']
drawer = draw_tab.__globals__
drawer['TabAccessor'] = Accessor
options = load_config(os.path.join(os.path.dirname(DRAWER), 'kitty.conf'))


def draw_data(edge):
    values = dict(
        leading_spaces=0, sep='', trailing_spaces=0, bell_on_tab=options.bell_on_tab, alpha=(),
        active_fg=options.active_tab_foreground, active_bg=options.active_tab_background,
        inactive_fg=options.inactive_tab_foreground, inactive_bg=options.inactive_tab_background,
        default_bg=options.background, title_template='', active_title_template=None, tab_activity_symbol='',
        powerline_style='slanted', tab_bar_edge=edge, max_tab_title_length=options.tab_title_max_length,
        max_tab_title_lines=CARD_ROWS, wrap_width=0, os_window_id=OS_WINDOW,
    )
    return DrawData(**{field: values[field] for field in DrawData._fields})


def tabs_for(count):
    drawer['get_boss'] = lambda: Boss(count)
    return [TabBarData(title='shell', is_active=n == 0, needs_attention=n == 1, tab_id=n + 1, os_window_id=OS_WINDOW) for n in range(count)]


def text(screen):
    return [str(screen.line(y)).rstrip() for y in range(screen.lines)]


def vertical(count, rows):
    'measure every tab, then draw them stacked flush: kitty also leaves a blank row between tabs while one fits'
    tabs, data, screen = tabs_for(count), draw_data('left'), Screen(None, rows, BAR_COLUMNS, 0, 10, 20)

    def one(n, row, for_layout):
        extra = ExtraData()
        extra.prev_tab = tabs[n - 1] if n else None
        extra.next_tab = tabs[n + 1] if n + 1 < count else None
        extra.for_layout = for_layout
        screen.cursor.x, screen.cursor.y = 0, row
        draw_tab(data._replace(max_tab_title_lines=min(CARD_ROWS, rows - row)), screen, tabs[n], 0, BAR_COLUMNS - 1, n + 1, True, extra)
        return screen.cursor.y - row + 1

    heights = [one(n, 0, True) for n in range(count)]
    screen.cursor.x = screen.cursor.y = 0
    screen.erase_in_display(2, False)
    row = 0
    for n, height in enumerate(heights):
        one(n, row, False)
        row += height
    return text(screen)


def horizontal(count):
    'one row: inactive tabs at an even share, the active one at whatever it asks for'
    tabs, data, screen = tabs_for(count), draw_data('bottom'), Screen(None, 1, ROW_COLUMNS, 0, 10, 20)
    for n, tab in enumerate(tabs):
        length = ROW_COLUMNS if tab.is_active else ROW_COLUMNS // count - 1
        draw_tab(data, screen, tab, screen.cursor.x, length, n + 1, n + 1 == count, ExtraData())
    return text(screen)


print(json.dumps({'cards': vertical(3, 12), 'panel': vertical(5, 12), 'lines': vertical(8, 9), 'pills': horizontal(3)}, ensure_ascii=False))
