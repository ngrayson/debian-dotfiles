#!/usr/bin/env python3

import sqlite3
import subprocess
from argparse import ArgumentParser
from configparser import ConfigParser
from os import environ
from pathlib import Path
from hashlib import sha256
from contextlib import closing, contextmanager, suppress
from tempfile import NamedTemporaryFile
from shutil import copyfile

cache_dir = Path(environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'rofi-bookmarks'
firefox_dir = Path.home() / '.mozilla/firefox'

# b/c sqlite databases are locked by firefox we need copy them into a temporary location and connect to them there
@contextmanager
def temp_sqlite(path):
    with NamedTemporaryFile() as temp_loc:
        copyfile(path, temp_loc.name)
        with closing(sqlite3.connect(temp_loc.name)) as conn:
            yield conn

# go through all installs and chose first profile you find.
# better option would be to use install (which firefox) but that would add a dependency on cityhash
def default_profile_path():
    installs = ConfigParser()
    installs.read(firefox_dir / 'installs.ini')
    for i in installs.values():
        with suppress(KeyError):
            return firefox_dir / i['Default']
    raise Exception("could not find a default profile in installs.ini")

# get Path to profile directory from profil name
def path_from_name(name):
    profiles = ConfigParser()
    profiles.read(firefox_dir / 'profiles.ini')
    for i in profiles.values():
        with suppress(KeyError):
            if i['Name'] == name:
                return firefox_dir / i['Path']
    raise Exception("no profile with this name")

# add icon file to cache (in ~/.cache/rofi-bookmarks)
def cache_icon(icon):
    loc = cache_dir / sha256(icon).hexdigest()
    if not cache_dir.exists():
        cache_dir.mkdir()
    if not loc.exists():
        loc.write_bytes(icon)
    return loc

# main function, finds all bookmaks inside of search_path and their corresponding icons and prints them in a rofi readable form
def write_rofi_input(profile_loc, search_path=[], sep=' / '):
    with temp_sqlite(profile_loc / 'places.sqlite') as places:
        conn_res = places.execute("""SELECT moz_bookmarks.id, moz_bookmarks.parent, moz_bookmarks.type, moz_bookmarks.title, moz_places.url
                                     FROM moz_bookmarks LEFT JOIN moz_places ON moz_bookmarks.fk=moz_places.id
                                  """).fetchall()

    by_id = {i: (title, parent) for i, parent, _, title, _ in conn_res}
    def parent_generator(i):  # gives generator, where next is title of parent
        while i > 1:
            title, i = by_id[i]
            yield title

    with temp_sqlite(profile_loc / 'favicons.sqlite') as favicons:
        for index, parent, type, title, url in conn_res:
            if type == 1 and url:  # type one means bookmark, and url must exist

                # Generate path and filter out None values
                path_list = [p for p in reversed(list(parent_generator(index))) if p is not None]

                # Check if the path matches the search_path
                if len(path_list) >= len(search_path) and all(path_list[i] == search_path[i] for i in range(len(search_path))):
                    path = sep.join(path_list[len(search_path):]) if len(path_list) > len(search_path) else (title or "Untitled")
                    icon = favicons.execute(f"""SELECT max(ic.data) FROM moz_pages_w_icons pg, moz_icons_to_pages rel, moz_icons ic
                                                                    WHERE pg.id = rel.page_id AND ic.id=rel.icon_id AND pg.page_url=?
                                             """ , (url,)).fetchone()[0]
                    if icon:
                        print(f"{path}\x00info\x1f{url}\x1ficon\x1f{cache_icon(icon)}")
                    else:
                        print(f"{path}\x00info\x1f{url}")

if __name__ == "__main__":
    parser = ArgumentParser(description="generate list of bookmarks with icons for rofi")
    parser.add_argument('path',              default="",    nargs='?',      help="restrict list to a bookmark folder")
    parser.add_argument('-s', '--separator', default=" / ", metavar='sep',  help="seperator for paths")
    parser.add_argument('-p', '--profile',                  metavar='prof', help="firefox profile to use")
    args, _ = parser.parse_known_args()   # rofi gives us selected entry as additional argument -> ignore (not useful)

    if environ.get('ROFI_RETV') == '1':
        prof = [] if args.profile is None else ["-P", args.profile]
        subprocess.Popen(["firefox", environ['ROFI_INFO']] + prof, close_fds=True, start_new_session=True, stdout=subprocess.DEVNULL)
    else:
        search_path = [i for i in args.path.split('/') if i != '']
        profile_path = default_profile_path() if args.profile is None else path_from_name(args.profile)

        print("\x00prompt\x1f ")  # change prompt
        write_rofi_input(profile_path, search_path=search_path, sep=args.separator)
