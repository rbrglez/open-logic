import os
import argparse
import platform
from pathlib import Path

# Change directory to the script directory
os.chdir(Path(__file__).parent)

# Detect arguments
parser = argparse.ArgumentParser(description='Lint all VHDL files in the project')
parser.add_argument('--debug', action='store_true', help='Lint files one by one and stop on any errors')
parser.add_argument('--syntastic', action='store_true', help='Output in syntastic format')

args = parser.parse_args()

# Define the directory to search
DIR = '../..'

# Not linted files
NOT_LINTED = ["RbExample.vhd"] # Docmentation example, incomplete VHDL
NOT_LINTED_DIR = ["../../3rdParty/"] # 3rd party libraries

# Windows has a command length limit of 8192. We therefore chunk files
# into smaller pieces on Windows (not on linux to avoid speed penalty).
# Size chosen: 8192 / 256 (max path length) = 32. USe 30 to leave some
# characters for the rest of the command
def chunked_files(files):
    WIN_CHUNK_SIZE = 30
    if platform.system().lower() == "windows":
        for i in range(0, len(files), WIN_CHUNK_SIZE):
            yield files[i:i+WIN_CHUNK_SIZE]
    else:
        yield files

def files_to_string(string, file_paths):
    return string.join(str(path) for path in file_paths)

def root_is_vc(root):
    return root.name == 'tb' and root.parent.name == 'test'

def find_normal_vhd_files(directory):
    vhd_files = []
    
    for file in directory.rglob('*.vhd'):
        # Skip directories that are not relevant (including subdirectories)
        if any(file.resolve().is_relative_to(Path(not_linted).resolve()) for not_linted in NOT_LINTED_DIR):
            continue
            
        # Skip VC files
        if root_is_vc(file.parent):
            continue
            
        # Skip not linted files
        if file.name in NOT_LINTED:
            continue
            
        #Append file
        vhd_files.append(file.resolve())
    return vhd_files

def find_vc_vhd_files(directory):
    vhd_files = []
    
    for file in directory.rglob('*.vhd'):
        # Only add VC files
        if root_is_vc(file.parent):
            vhd_files.append(file.resolve())
    return vhd_files

# Configure output format
output_format = "-of vsg"
if args.syntastic:
    output_format = "-of syntastic"

# Get the list of .vhd files
vhd_files_list = find_normal_vhd_files(Path(DIR))
vc_files_list = find_vc_vhd_files(Path(DIR))

# Print the list of files found
print("Normal VHDL Files")
print(files_to_string("\n", vhd_files_list))
print()
print("VC VHDL Files")
print(files_to_string("\n", vc_files_list))
print()
print("Start Linting")

error_occurred = False

# Execute linting for normal VHD files
if args.debug:
    for file in vhd_files_list:
        print(f"Linting {file}: Normal Config")
        result = os.system(f'vsg -c ../config/vsg_config.yml -f {file} {output_format}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    for chunk in chunked_files(vhd_files_list):
        all_files = files_to_string(" ", chunk)
        result = os.system(f'vsg -c ../config/vsg_config.yml -f {all_files} --junit ../report/vsg_normal_vhdl.xml --all_phases {output_format}')
        if result != 0:
            error_occurred = True
    
# Execute linting for VC VHD files
if args.debug:
    for file in vc_files_list:
        print(f"Linting {file}: VC Config")
        result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml -f {file} {output_format}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    for chunk in chunked_files(vc_files_list):
        all_files = files_to_string(" ", chunk)
        result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml -f {all_files} --junit ../report/vsg_vc_vhdl.xml --all_phases {output_format}')
        if result != 0:
            error_occurred = True

if error_occurred:
    raise Exception(f"Error: Linting of VHDL files failed - check report")

# Print success message
print("All VHDL files linted successfully")


