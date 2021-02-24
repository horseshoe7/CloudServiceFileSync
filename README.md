# CloudSyncSandbox

*NOTE* Until this product reaches v.1.0, please consider everything you find as a work-in-progress.  This includes Documentation too!

(If you need help, please just email me and we can discuss)

The purpose of this project is to define a set of protocols that describe a file syncable process, that you then can implement for concrete cloud storage solutions, such as iCloud or Dropbox.

The hope is that one interface can cover the various cloud services.

Things I want to be able to do:

- Sync a Root Folder
- Import a File
- Import File(s)  // this will be cloud service dependent, as they probably have their own pickers.


Things that any project needs to configure:

- which UTI's to include in your project (for the file types you are interested in)
- Cloud service specifics, such as folder names, etc.
- 


Concepts:

CloudServiceController is intended to work like a final class (continue designing)
    - it keeps a CloudStorageController instance
    - it does work on background threads
    - CloudStorageController runs on the calling thread and makes no considerations for threading
    
    
You instantiate a CloudServiceController with an instance of CloudStorageController and a AppFileHandling instance.

AppFileHandling is your bridge between the local filesystem and your object types that are being synced

## Cloud Service Support

Currently this only supports iCloud and Dropbox

### Configure Document Types your app will support

Info.plist needs to register to work with document types.  Say I want to be able to work with images and text.  I can use the Xcode UI, which just displays what you could add directly to your Info.plist

```
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Images</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.image</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Text Files</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.text</string>
        </array>
    </dict>
</array>
```


### Support iCloud

Need to enable capabilities for iCloud, iCloud Documents services, then choose a container and make note of its identifier.  (we'll use "com.hometeam.iCloud.files")

You then need to indicate that your app can expose its iCloud folder to other apps, such as Files / iCloud Drive:

In your Info.plist file, add:
```
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

Then you should add to your Info.plist info about iCloud:
```
<key>NSUbiquitousContainers</key>
<dict>
    <key>com.hometeam.iCloud.files</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>My iCloud App</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>One</string>
    </dict>
</dict>
```
Note: This whole sync kit is designed for one folder, flat hierarchy of files.  You might need to bump your bundle version to see changes in the Files app.  (There is some info about that here:  https://stackoverflow.com/a/29886806/421797)

#### Potential Issues, Further Info

IF, in the Settings App > iCloud > Manage Storage, the associated name seems to be taken from a 'technical' string, and is not a 'user facing' string, there's this info about that:

https://stackoverflow.com/a/10167614/421797


Most of this iCloud portion was derived from the following two links and some searching on stackoverflow.com

https://theswiftdev.com/how-to-use-icloud-drive-documents/
https://www.appcoda.com/files-app-integration/

### Support Dropbox

Generally follows the instructions of the SwiftyDropbox module, given here: https://github.com/dropbox/SwiftyDropbox#configure-your-project

#### Add to Podfile?

#### Configure 

- find your app's APP_KEY and SECRET from the Dropbox Developers App Console for your app.  This info should populate a DropboxConfig value
- Add to Application .plist file (https://github.com/dropbox/SwiftyDropbox#application-plist-file)


## Installation

### Download the Source and Inspect the Tests

#### If it doesn't build:

In order to not share Dropbox credentials, you should create an extension that satisfies the build error:
```
import Foundation
import CloudServiceFileSync

extension DropboxConfig {
    static func forApplication() -> DropboxConfig {
        let dropboxConfig = DropboxConfig(appKey: "[SomeAppKeyOfYours]", secret: "[SomeAppSecretOfYours]")
        return dropboxConfig
    }
}
```
