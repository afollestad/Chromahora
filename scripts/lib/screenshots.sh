# shellcheck shell=bash
# Shared by setup.sh and screenshots.sh.

# An iPhone at 1206 by 2622 pixels, which App Store Connect takes for its 6.1- and 6.3-inch
# displays, an iPhone Duo's inner display at 2853 by 2007, which it requires from April 2027 of
# apps built with the iOS 27.1 SDK, a 13-inch iPad at 2064 by 2752, which it scales down for the
# smaller ones, and a 46mm watch at 416 by 496. The watch is also `run.sh -w`'s.
screenshot_devices=("iPhone 18 Pro" "iPhone Duo" "iPad Pro 13-inch (M5) (16GB)" "Apple Watch Series 12 (46mm)")
