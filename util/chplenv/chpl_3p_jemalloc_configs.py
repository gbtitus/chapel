import os

import third_party_utils
from utils import memoize, run_command


@memoize
def get_uniq_cfg_path():
    return third_party_utils.default_uniq_cfg_path()

# Instead of libtool or pkg-config, jemalloc uses a jemalloc-config script to
# determine dependencies/link args . It's located in the bin directory
@memoize
def get_jemalloc_config_file():
    install_path = third_party_utils.get_cfg_install_path('jemalloc')
    config_file = os.path.join(install_path, 'bin', 'jemalloc-config')
    return config_file

@memoize
def get_link_args(target_mem):
    if target_mem == 'jemalloc':
        jemalloc_config = get_jemalloc_config_file()
        if os.access(jemalloc_config, os.X_OK):
            libdir = run_command([jemalloc_config, '--libdir']).strip()
            libs = ['-L' + libdir, '-Wl,-rpath,' + libdir, '-ljemalloc']
            libs += run_command([jemalloc_config, '--libs']).strip().split()
        else:
            libs = ['-ljemalloc']
        return libs
    elif target_mem == 'system':
        return ['-ljemalloc']
    else:
        return []
