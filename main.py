import zlib
import argparse
from os import listdir
from os.path import isfile, normpath
from random import randint
from base64 import b64encode, b64decode
from rubymarshal.reader import load
from rubymarshal.writer import write

def compile(scripts_directory, output_file):
    scripts = []
    dir_list = listdir(scripts_directory)
    for file in dir_list:
        filename = scripts_directory + '/' + file
        if isfile(filename) and '.rb' in file:
            random_number = str(randint(100000,999999))
            title = file[4:-3]
            title = title.replace('[BACKSLASH]','/')
            with open(filename, 'rb') as f:
                script = zlib.compress(b64encode(f.read()))
            scripts.append([random_number, title, script])
    with open(output_file, 'wb') as f:
        write(f, scripts)
    print("Scripts compiled to {}".format(output_file))

def decompile(input_file, scripts_directory):
    with open(input_file, 'rb') as f:
        scripts = load(f)
    for i, script in enumerate(scripts):
        title = f"{str(i).zfill(len(str(len(scripts))))}_{script[1]}"
        title = title.replace('/','[BACKSLASH]')
        with open(f'{scripts_directory}/{title}.rb', 'wb') as f:
            f.write(b64decode(zlib.decompress(script[2])))
    print("Scripts extracted to {}".format(scripts_directory))

parser = argparse.ArgumentParser(
    description="A simple command line tool to Compile/Decompile Xenoverse Scripts"
)

compile_decompile_group = parser.add_mutually_exclusive_group(required=True)

compile_decompile_group.add_argument(
    '-c', '--compile',
    dest='c',
    help='Compile scripts to XVD file',
    action='store_true'
)

compile_decompile_group.add_argument(
    '-d', '--decompile',
    dest='d',
    help='Decompile scripts from XVD file',
    action='store_true'
)

parser.add_argument(
    'directory',
    help='Directory to/for Extracted Scripts',
    action='store'
)

parser.add_argument(
    'file',
    help='Path to/for Compiled Scripts File',
    action='store'
)

if __name__ == '__main__':
    args = parser.parse_args()
    directory = normpath(args.directory)
    file = normpath(args.file)
    if args.c:
        compile(directory, file)
    elif args.d:
        decompile(file, directory)