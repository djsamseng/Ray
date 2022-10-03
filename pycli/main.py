
import argparse
import time
import urllib, urllib.error, urllib.request

import cv2

def get_cap(url):
  try:
    res = urllib.request.urlopen(url)
  except urllib.error.URLError:
    print("Could not open:", url)
    return
  if res.getcode() != 200:
    return
  print("Opened:", url)
  cap = cv2.VideoCapture(url)
  return cap

def show_until_exit(host:str, skip:int):
  color_url = host + ":10001"
  color_cap = get_cap(color_url)

  do_continue = True

  itr = 0
  while do_continue:
    if color_cap == None:
      time.sleep(1)
      color_cap = get_cap(color_url)

    if color_cap is not None:
      color_cap.grab()
      ret, frame = color_cap.retrieve()
      if ret:
        cv2.imshow("Frame", frame)
    itr += 1
    if itr % (skip+1) == 0:
      ret = cv2.waitKey(1)
      if ret >= 0:
        do_continue = False

  color_cap.release()
  cv2.destroyAllWindows()


def parse_args():
  parser = argparse.ArgumentParser()
  parser.add_argument("--host", dest="host", type=str, default="http://192.168.1.211")
  parser.add_argument("--skip", dest="skip", type=int, default=1, help="Skip this number of frames before calling waitKey. Otherwise we may fall behind grabbing frames")
  return parser.parse_args()

def main():
  args = parse_args()
  show_until_exit(host=args.host, skip=args.skip)

if __name__ == "__main__":
  main()
