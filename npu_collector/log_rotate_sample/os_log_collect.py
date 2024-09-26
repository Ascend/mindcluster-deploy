import time
import argparse
import os


def command():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input_file', type=str, required=True,
                        help='输入OS系统日志文件')
    parser.add_argument('-o', '--out_file', type=str, required=True,
                        help='转存OS系统日志文件')
    parser.add_argument('-t', '--interval_time', type=int, required=False, default=5,
                        help='采集周期')
    return parser.parse_args()


def rotate_os_log(os_log_file, out_file, interval_time):
    with open(os_log_file, 'r') as f:
        last_pos = sum(1 for line in f)
    while True:
        with open(os_log_file, 'r') as f:
            cur_pos = sum(1 for line in f)
        if cur_pos >= last_pos:
            with open(os_log_file, 'r') as f:
                lines = f.readlines()[last_pos:cur_pos]
        else:
            with open(os_log_file, 'r') as f:
                lines = f.readlines()[:cur_pos]
        if lines:
            with os.fdopen(os.open(out_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o640), 'a+') as f:
                f.write(''.join(lines))
        last_pos = cur_pos
        time.sleep(interval_time)


if __name__ == '__main__':
    args = command()
    rotate_os_log(args.input_file, args.out_file, args.interval_time)