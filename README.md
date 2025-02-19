# Play!

Play! is a PlayStation 2 emulator for Windows, macOS, UNIX, Android & iOS platforms.

Compatibility information is available on the official [Compatibility Tracker](https://github.com/jpd002/Play-Compatibility). If a specific game
doesn't work with the emulator, please create a new issue there.

For more information, please visit [purei.org](http://purei.org).

## Building ##

### Getting Started ###
First you'll need to clone this repo which contains the emulator source code, along side the submodules required to build Play!.
```
git clone --recurse-submodules https://github.com/jpd002/Play-.git
cd Play-
```

### Building for Windows ###
The Easiest way to build the project on windows is to open Qt Creator and directed it to the cmake file in /project/dir/Play-/CMakeLists.txt.
You can also build the project using Visual Studio or cmdline, for that you must follow these isnstruction:
To build for Windows you will need to have CMake installed on your system.
```
mkdir build
cd build
```
```
# Not specifying -G would automatically generate 32-bit projects.
cmake .. -G"Visual Studio 15 2017 Win64" -DCMAKE_PREFIX_PATH="C:\Qt\5.10.1\msvc2017_64" -DUSE_QT=YES
```
You can now build the project by opening the generated Visual Studio Solution or continue through cmdline:
```
cmake --build . --config Release
```
Note: --config can take any of Release/Debug/RelWithDebInfo

### Building for macOS & iOS ###
If you don't have CMake installed on your system, you can install it using brew with the following command: `brew install cmake`.

There are two ways to generate a build for macOS, either by using makefiles or by using Xcode.
```
mkdir build
cd build
```
```
# Not specifying -G would automatically pick Makefiles
cmake .. -G"Xcode" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=~/Qt/5.1.0/clang_64/
cmake --build . --config Release
# OR
cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=~/Qt/5.1.0/clang_64/
cmake --build .
```
To generate a build for iOS, you will need to add the following parameters to the CMake invocation:
`-DCMAKE_TOOLCHAIN_FILE=../../../Dependencies/cmake-ios/ios.cmake -DTARGET_IOS=ON`

iOS build doesnt use Qt so please omit `-DCMAKE_PREFIX_PATH=...`

Note: while iOS build can be generated with Makefiles, they will not be FAT binaries.

Example:
`cmake .. -G"Xcode" -DCMAKE_TOOLCHAIN_FILE=../deps/Dependencies/cmake-ios/ios.cmake -DTARGET_IOS=ON`

### Building for UNIX ###
if you dont have cmake or openal lib installed, you'll also require Qt (preferably version 5.6) you can install it using your OS packaging tool, e.g ubuntu `apt install cmake libalut-dev`
on UNIX systems there is 3 ways to setup a build, using qt creator, makefile or Ninja
 - QT Creator
    - Open Project -> `Play/CMakeLists.txt`

 - Makefile/Ninja
```
mkdir build
cd build
```
```
# Not specifying -G would automatically pick Makefiles
cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/qt56/
cmake --build .
# OR
cmake .. -G"Ninja" -DCMAKE_PREFIX_PATH=/opt/qt56/
cmake --build . --config Release
```
Note `CMAKE_PREFIX_PATH` refers to the qt directory containing bin/libs folder, the above example uses a backport repo to install qt5.6 on trusty, if you install qt from qt offical website, your `CMAKE_PREFIX_PATH` might look like this `~/Qt5.6.0/5.6/gcc_64/`

### Building for Android ###

Building for Android has been tested on macOS and UNIX environments.
Android can be built using Android Studio or through Gradle.

- Android Studio:
   - Files->Open Projects->Directory To `Play/build_android`
   - Install NDK using sdk manager
   - edit/create `Play/build_android/local.properties`
      - OSX: add a newline `ndk.dir=/Users/USER_NAME/Library/Android/sdk/ndk-bundle` replacing `USER_NAME` with your macOS username
      - UNIX: add a newline `ndk.dir=~/Android/Sdk/ndk-bundle`
      - Windows: add a newline `C:\Users\USER_NAME\AppData\Local\Android\sdk\ndk-bundle`
      - Please Leave an empty new line at the end of the file

Note, these examples are only valid if you installed NDK through Android Studio's SDK manager.
Otherwise you must specify the correct location to Android NDK.
Once this is done, you can start the build.

- Gradle: Prerequisite Android SDK & NDK (Both can be installed through Android Studio)
   - edit/create `Play/build_android/local.properties`
      - OSX:
        - add a newline `sdk.dir=/Users/USER_NAME/Library/Android/sdk` replacing `USER_NAME` with your macOS username
        - add a newline `ndk.dir=/Users/USER_NAME/Library/Android/sdk/ndk-bundle` replacing `USER_NAME` with your macOS username
      - UNIX:
        - add a newline `sdk.dir=~/Android/Sdk`
        - add a newline `ndk.dir=~/Android/Sdk/ndk-bundle`
      - Windows:
        - add a newline `sdk.dir=C:\Users\USER_NAME\AppData\Local\Android\sdk`
        - add a newline `ndk.dir=C:\Users\USER_NAME\AppData\Local\Android\sdk\ndk-bundle`
      - Please Leave an empty new line at the end of the file

Note, these examples are only valid if you installed NDK through Android Studio's SDK manager.
Otherwise you must specify the correct location to Android NDK.
Once this is done, you can start the build.
```
cd Play/build_android
sh gradlew assembleDebug
```
##### about Release/Signed builds. #####

Building through Android Studio, you have the option to “Generate Signed APK”.

Building through Gradle, you must create a text file `Play/build_android/keystore.properties` and add the following properties to it, `storeFile`,`storePassword`,`keyAlias`,`keyPassword`.
E.g of `keystore.properties`
```
storeFile=/location/to/my/key.jks
storePassword=mysuperhardpassword
keyAlias=myalias
keyPassword=myevenharderpassword
```
Please Leave an empty new line at the end of the file
```
cd Play/build_android
sh gradlew assembleRelease
# or on Windows
gradlew.bat assembleRelease
```
