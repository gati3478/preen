# The tab bar's drawer (tab_bar_style custom), for either orientation.
#
# Vertical (tab_bar_edge left or right). kitty's vertical bar does not scroll:
# a tab that does not fit is not drawn. So the bar has three densities, each
# drawn for every tab alike, and takes the roomiest in which all tabs fit;
# nothing moves when the active tab changes, only colour does. Past one tab a
# row, in the last density, kitty drops the trailing tabs for an ellipsis.
#
#   cards   a closed, rounded card of three rows per tab: the top edge carries
#           the index and the directory's name the way a titled panel does,
#           the middle row what runs there (the window title, behind the bell
#           and any program status)
#   panel   the cards joined into one rounded panel, a tab's top edge being
#           the divider from the tab above: two rows per tab and one to close
#   lines   one row: index, bell, status and name, a bar marking the active tab
#
# Horizontal (top or bottom), for a screen too narrow to give up columns.
# kitty's horizontal bar is one row, so a tab is a soft pill holding its index
# and name, and the active one, a step lighter, adds what runs there after the
# name. Inactive tabs share the columns evenly and the active tab has the rest;
# a tab too narrow for a name keeps its index and, with a cell to spare, one
# glyph.
#
# A tab's directory is the one its shell last reported (OSC 7), which a
# program started there does not move; with no report, or behind ssh, the
# oldest foreground process's. kitty's `launch --cwd=last_reported` reads the
# same report, so cmd+t opens where the name says.
#
# Whose Claude Code session a tab holds is read from CSHIP_ACCOUNT in the
# environment of the tab's oldest foreground process, a JSON object whose
# organization_name a launcher sets. It colours the index, gold for the
# personal account and purple for any other, and draws a strip in that
# colour: a heavy run of a card's or panel's top edge, an underline beneath a
# pill's index. A tab with no session has neither.
#
# Outlines ride the theme's tab colours: the active tab's outline and name
# are active_tab_background, the rest inactive_tab_background, and an
# inactive tab's second line is inactive_tab_foreground. A pill's fill is
# inactive_tab_background when active and halfway to the background
# otherwise. The remaining text colours are the Gruvbox constants below.
import enum
import json
import os

from kitty.fast_data_types import Color, Screen, get_boss, truncate_point_for_length, wcswidth
from kitty.tab_bar import DrawData, ExtraData, TabAccessor, TabBarData, as_rgb
from kitty.utils import color_as_int, path_from_osc7_url

GOLD = as_rgb(0xFABD2F)
PURPLE = as_rgb(0xD3869B)
RED = as_rgb(0xFB4934)
INDEX_PLAIN = as_rgb(0x7C6F64)
NAME = as_rgb(0xD5C4A1)
DETAIL_ACTIVE = as_rgb(0xBDAE93)

ACCOUNT_VARIABLE = 'CSHIP_ACCOUNT'
PERSONAL_ACCOUNT = 'personal'
INDEX_WIDTH = 2
GAP = '  '
MIN_STRIP = 4
MIN_PILL_NAME = 3
MIN_PILL_DETAIL = 6
PILL_OVERHEAD = 4
DETAIL_SEPARATOR = ' · '
PILL_LEFT = '\ue0b6'
PILL_RIGHT = '\ue0b4'
UNDERLINE = 1
NO_DECORATION = 0


class Density(enum.Enum):
    CARDS = 3
    PANEL = 2
    LINES = 1


_account_colors: dict[int, int] = {}


def _cut(text: str, width: int) -> str:
    'text cut to width cells, with an ellipsis when cut'
    if width <= 0:
        return ''
    if wcswidth(text) > width:
        text = text[: truncate_point_for_length(text, width - 1)] + '…'
    return text


def _kitty_tab(tab: TabBarData):
    boss = get_boss()
    return boss.tab_for_id(tab.tab_id) if boss else None


def _name_of(directory: str, fallback: str) -> str:
    if directory == os.path.expanduser('~'):
        return '~'
    return os.path.basename(directory.rstrip('/')) or directory or fallback


def _directory(window) -> str:
    "what the shell last reported, as kitty's --cwd=last_reported reads it, else the oldest foreground process's directory"
    if window is None:
        return ''
    reported = window.screen.last_reported_cwd
    if reported and not window.child_is_remote:
        path = path_from_osc7_url(reported)
        if path:
            return path
    return window.get_cwd_of_child(oldest=True) or ''


def _directory_name(tab: TabBarData) -> str:
    kitty_tab = _kitty_tab(tab)
    return _name_of(_directory(kitty_tab.active_window if kitty_tab else None), tab.title)


def _blend(a: Color, b: Color) -> int:
    return as_rgb(((a.red + b.red) // 2 << 16) | ((a.green + b.green) // 2 << 8) | (a.blue + b.blue) // 2)


def _account_color(tab: TabBarData) -> int:
    from kitty.child import environ_of_process

    kitty_tab = _kitty_tab(tab)
    window = kitty_tab.active_window if kitty_tab else None
    pid = window.child.get_pid_for_cwd(oldest=True) if window else None
    if pid is None:
        return INDEX_PLAIN
    if pid in _account_colors:
        return _account_colors[pid]
    try:
        raw = environ_of_process(pid).get(ACCOUNT_VARIABLE)
        color = GOLD if json.loads(raw).get('organization_name') == PERSONAL_ACCOUNT else PURPLE
    except Exception:
        # No session, or not yet: a launcher that execs into one keeps its
        # pid, so only an answer is remembered.
        return INDEX_PLAIN
    if len(_account_colors) > 256:
        _account_colors.clear()
    _account_colors[pid] = color
    return color


def _tab_count(tab: TabBarData) -> int:
    boss = get_boss()
    manager = boss.os_window_map.get(tab.os_window_id) if boss else None
    return len(manager.tabs) if manager else 0


def _density(tab: TabBarData, screen: Screen) -> Density:
    'the roomiest density at which every tab is drawn'
    count = _tab_count(tab)
    if count * Density.CARDS.value <= screen.lines:
        return Density.CARDS
    if count * Density.PANEL.value + 1 <= screen.lines:
        return Density.PANEL
    return Density.LINES


def draw_tab(
    draw_data: DrawData, screen: Screen, tab: TabBarData, before: int, max_tab_length: int, index: int, is_last: bool, extra_data: ExtraData
) -> int:
    if draw_data.tab_bar_edge in ('left', 'right'):
        return _draw_vertical(draw_data, screen, tab, index, extra_data)
    return _draw_horizontal(draw_data, screen, tab, max_tab_length, index)


def _draw_vertical(draw_data: DrawData, screen: Screen, tab: TabBarData, index: int, extra_data: ExtraData) -> int:
    first_row = screen.cursor.y
    density = _density(tab, screen)
    joined = density is Density.PANEL
    closes = not joined or extra_data.next_tab is None
    height = density.value + (1 if joined and closes else 0)
    rows = min(max(1, draw_data.max_tab_title_lines), height)
    if extra_data.for_layout:
        # kitty clears the bar in the cursor's background after measuring.
        screen.cursor.bg = 0
        screen.cursor.y = first_row + rows - 1
        return screen.cursor.x

    ground = as_rgb(color_as_int(draw_data.default_bg))
    active = as_rgb(color_as_int(draw_data.active_bg))
    quiet = as_rgb(color_as_int(draw_data.inactive_bg))
    outline = active if tab.is_active else quiet
    columns = screen.columns

    def row(offset: int, *spans: tuple[int, str, bool]) -> None:
        if offset >= rows:
            return
        screen.cursor.x, screen.cursor.y = 0, first_row + offset
        screen.cursor.bg = ground
        screen.cursor.italic = False
        used = 0
        for fg, text, bold in spans:
            screen.cursor.fg, screen.cursor.bold = fg, bold
            screen.draw(text)
            used += wcswidth(text)
        screen.cursor.bold = False
        screen.draw(' ' * max(0, columns - used))

    account = _account_color(tab)
    index_text = f'{index:>{INDEX_WIDTH}}' + GAP
    name_color = active if tab.is_active else NAME
    bell = draw_data.bell_on_tab if tab.needs_attention else ''
    status = TabAccessor(tab.tab_id).program_status if get_boss() else ''

    if density is Density.LINES:
        bar = (active, ' ▌ ', False) if tab.is_active else (ground, '   ', False)
        width = columns - 4 - len(index_text) - wcswidth(bell) - wcswidth(status)
        row(0, bar, (account, index_text, tab.is_active), (RED, bell, False), (name_color, status + _cut(_directory_name(tab), width), tab.is_active))
    else:
        # ' ╭─ ' index name ' ' strip '─╮' and a column of margin. In a panel
        # the top edge is shared with the tab above, so it is lit for either.
        above = extra_data.prev_tab if joined else None
        rule = active if tab.is_active or (above is not None and above.is_active) else quiet
        left, right = ('├', '┤') if above is not None else ('╭', '╮')
        name = _cut(_directory_name(tab), columns - 4 - len(index_text) - 4 - MIN_STRIP)
        strip = columns - 4 - len(index_text) - wcswidth(name) - 4
        has_account = account != INDEX_PLAIN
        row(
            0,
            (rule, f' {left}─ ', False),
            (account, index_text, tab.is_active),
            (name_color, name + ' ', tab.is_active),
            (account if has_account else rule, ('━' if has_account else '─') * strip, False),
            (rule, '─' + right, False),
        )
        width = columns - 7 - wcswidth(bell) - wcswidth(status)
        detail = status + _cut(tab.title, width)
        detail_color = DETAIL_ACTIVE if tab.is_active else as_rgb(color_as_int(draw_data.inactive_fg))
        row(
            1,
            (outline, ' │  ', False),
            (RED, bell, False),
            (detail_color, detail + ' ' * (width + wcswidth(status) - wcswidth(detail)), False),
            (outline, ' │', False),
        )
        if closes:
            row(2, (outline, ' ╰' + '─' * (columns - 4) + '╯', False))

    screen.cursor.bg = 0
    screen.cursor.y = first_row + rows - 1
    return screen.cursor.x


def _draw_horizontal(draw_data: DrawData, screen: Screen, tab: TabBarData, max_tab_length: int, index: int) -> int:
    ground = as_rgb(color_as_int(draw_data.default_bg))
    pill = as_rgb(color_as_int(draw_data.inactive_bg)) if tab.is_active else _blend(draw_data.default_bg, draw_data.inactive_bg)
    account = _account_color(tab)
    index_text = str(index)
    # a mark is its glyph and one space here; the vertical bar keeps kitty's two
    bell = draw_data.bell_on_tab.strip() + ' ' if tab.needs_attention else ''
    status = TabAccessor(tab.tab_id).program_status.strip() if get_boss() else ''
    status = status + ' ' if status else ''

    # Two caps, the index, a space, the marks and text, and a column between
    # tabs. An inactive tab keeps to an even share of the bar by itself: kitty
    # holds back a column for every tab it has to cut, and gives the active
    # tab only what is left.
    if not tab.is_active:
        max_tab_length = min(max_tab_length, max(1, screen.columns // max(1, _tab_count(tab)) - 1))
    room = max_tab_length - len(index_text) - PILL_OVERHEAD
    marks = wcswidth(bell) + wcswidth(status)
    name = _directory_name(tab)
    detail = ''
    if room >= marks + min(MIN_PILL_NAME, wcswidth(name)):
        name = _cut(name, room - marks)
        left = room - marks - wcswidth(name) - wcswidth(DETAIL_SEPARATOR)
        if tab.is_active and left >= min(MIN_PILL_DETAIL, wcswidth(tab.title)):
            detail = _cut(tab.title, left)
    else:
        name = ''
        bell, status = bell.strip(), '' if bell else status.strip()
        if room < 1:
            # no cell for the bell: the index carries its red
            account = RED if bell else account
            bell = status = ''

    def draw(fg: int, text: str, bold: bool = False, bg: int = pill) -> None:
        screen.cursor.fg, screen.cursor.bg, screen.cursor.bold = fg, bg, bold
        screen.draw(text)

    screen.cursor.italic = False
    draw(pill, PILL_LEFT, bg=ground)
    if account in (GOLD, PURPLE):
        screen.cursor.decoration, screen.cursor.decoration_fg = UNDERLINE, account
    draw(account, index_text, tab.is_active)
    screen.cursor.decoration, screen.cursor.decoration_fg = NO_DECORATION, 0
    if name or bell or status:
        draw(account, ' ')
        draw(RED, bell)
        draw(as_rgb(color_as_int(draw_data.active_bg)) if tab.is_active else NAME, status + name, tab.is_active)
    if detail:
        draw(INDEX_PLAIN, DETAIL_SEPARATOR)
        draw(DETAIL_ACTIVE, detail)
    draw(pill, PILL_RIGHT, bg=ground)
    draw(0, ' ', bg=ground)
    screen.cursor.bg = 0
    return screen.cursor.x


# end of tab_bar.py: install.sh refuses a copy whose last line is not this one
