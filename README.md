
# Ray

Streams ARKit Data to Python over your local network

## Install
1. `pip3 install numpy opencv-python`

## Run
1. Run on an iPhone
2. open `pycli/receiver.py` and change `addr` to the IP address of your iPhone (printed in the Xcode logs)
3. Run `python3 pycli/receiver.py --armode` if `AppDelegate.swift` creates a `ContentView`
4. Run `python3 pycli/receiver.py` if `AppDelegate.swift` creates a `LidarContentView`

## Audio Not Streaming
1. Quit Xcode
2. `pkill -9 Python` or `pkill -9 python3`
3. Try again
