#!/usr/bin/env python3
"""Generate a minimal Xcode project for MyTop10 (SwiftUI + SPM)."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "MyTop10"
PROJ = ROOT / "MyTop10.xcodeproj"
PROJ.mkdir(parents=True, exist_ok=True)

def xid() -> str:
    return uuid.uuid4().hex[:24].upper()

PROJECT_ID = xid()
TARGET_ID = xid()
SOURCES_PHASE = xid()
RESOURCES_PHASE = xid()
FRAMEWORKS_PHASE = xid()
MAIN_GROUP = xid()
PRODUCTS_GROUP = xid()
APP_GROUP = xid()
PRODUCT_REF = xid()
CONFIG_LIST_PROJECT = xid()
CONFIG_LIST_TARGET = xid()
DEBUG_PROJECT = xid()
RELEASE_PROJECT = xid()
DEBUG_TARGET = xid()
RELEASE_TARGET = xid()
NATIVE_TARGET = TARGET_ID

# SPM
FIREBASE_PKG = xid()
SUPABASE_PKG = xid()
ADS_PKG = xid()
FIREBASE_AUTH_PROD = xid()
FIREBASE_CORE_PROD = xid()
SUPABASE_PROD = xid()
ADS_PROD = xid()
PKG_REFS = xid()

swift_files: list[Path] = sorted(APP.rglob("*.swift"))
resource_files = [
    APP / "Resources" / "Info.plist",
    APP / "Resources" / "Config.plist",
    APP / "Resources" / "Config.example.plist",
]
asset_catalog = APP / "Resources" / "Assets.xcassets"

file_entries: list[tuple[str, str, Path, str]] = []  # id, build_id, path, typ

def add_file(path: Path, typ: str) -> tuple[str, str]:
    fid, bid = xid(), xid()
    file_entries.append((fid, bid, path, typ))
    return fid, bid

swift_ids = [add_file(p, "sourcecode.swift") for p in swift_files]
resource_ids = []
for p in resource_files:
    if p.exists():
        resource_ids.append(add_file(p, "text.plist.xml"))
asset_id = add_file(asset_catalog, "folder.assetcatalog")

# Build file section
build_files = []
sources_build = []
resources_build = []
for fid, bid, path, typ in file_entries:
    build_files.append(f"\t\t{bid} /* {path.name} in Build */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};")
    if typ == "sourcecode.swift":
        sources_build.append(f"\t\t\t\t{bid} /* {path.name} in Sources */,")
    elif typ == "folder.assetcatalog" or path.name == "Info.plist":
        continue
    else:
        resources_build.append(f"\t\t\t\t{bid} /* {path.name} in Resources */,")

# Package product dependencies as build files
pkg_build_auth = xid()
pkg_build_core = xid()
pkg_build_supabase = xid()
pkg_build_ads = xid()
build_files += [
    f"\t\t{pkg_build_auth} /* FirebaseAuth in Frameworks */ = {{isa = PBXBuildFile; productRef = {FIREBASE_AUTH_PROD} /* FirebaseAuth */; }};",
    f"\t\t{pkg_build_core} /* FirebaseCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {FIREBASE_CORE_PROD} /* FirebaseCore */; }};",
    f"\t\t{pkg_build_supabase} /* Supabase in Frameworks */ = {{isa = PBXBuildFile; productRef = {SUPABASE_PROD} /* Supabase */; }};",
    f"\t\t{pkg_build_ads} /* GoogleMobileAds in Frameworks */ = {{isa = PBXBuildFile; productRef = {ADS_PROD} /* GoogleMobileAds */; }};",
]

file_refs = [
    f"\t\t{PRODUCT_REF} /* MyTop10.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MyTop10.app; sourceTree = BUILT_PRODUCTS_DIR; }};",
]
for fid, bid, path, typ in file_entries:
    rel = path.relative_to(ROOT).as_posix()
    if typ == "folder.assetcatalog":
        file_refs.append(
            f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {rel}; sourceTree = SOURCE_ROOT; }};"
        )
    else:
        last = "sourcecode.swift" if typ == "sourcecode.swift" else "text.plist.xml"
        file_refs.append(
            f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {last}; path = {rel}; sourceTree = SOURCE_ROOT; }};"
        )

# Flat group containing all files (simple, reliable)
children = "\n".join(
    f"\t\t\t\t{fid} /* {path.name} */," for fid, _, path, _ in file_entries
)

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{FRAMEWORKS_PHASE} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{pkg_build_auth} /* FirebaseAuth in Frameworks */,
				{pkg_build_core} /* FirebaseCore in Frameworks */,
				{pkg_build_supabase} /* Supabase in Frameworks */,
				{pkg_build_ads} /* GoogleMobileAds in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{MAIN_GROUP} = {{
			isa = PBXGroup;
			children = (
				{APP_GROUP} /* MyTop10 */,
				{PRODUCTS_GROUP} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{APP_GROUP} /* MyTop10 */ = {{
			isa = PBXGroup;
			children = (
{children}
			);
			name = MyTop10;
			sourceTree = "<group>";
		}};
		{PRODUCTS_GROUP} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{PRODUCT_REF} /* MyTop10.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{NATIVE_TARGET} /* MyTop10 */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "MyTop10" */;
			buildPhases = (
				{SOURCES_PHASE} /* Sources */,
				{FRAMEWORKS_PHASE} /* Frameworks */,
				{RESOURCES_PHASE} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = MyTop10;
			packageProductDependencies = (
				{FIREBASE_AUTH_PROD} /* FirebaseAuth */,
				{FIREBASE_CORE_PROD} /* FirebaseCore */,
				{SUPABASE_PROD} /* Supabase */,
				{ADS_PROD} /* GoogleMobileAds */,
			);
			productName = MyTop10;
			productReference = {PRODUCT_REF} /* MyTop10.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJECT_ID} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
			}};
			buildConfigurationList = {CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject "MyTop10" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {MAIN_GROUP};
			packageReferences = (
				{FIREBASE_PKG} /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,
				{SUPABASE_PKG} /* XCRemoteSwiftPackageReference "supabase-swift" */,
				{ADS_PKG} /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */,
			);
			productRefGroup = {PRODUCTS_GROUP} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{NATIVE_TARGET} /* MyTop10 */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{RESOURCES_PHASE} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(resources_build)}
				{asset_id[1]} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{SOURCES_PHASE} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(sources_build)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{DEBUG_PROJECT} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{RELEASE_PROJECT} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{DEBUG_TARGET} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = MyTop10/Resources/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = MyTop10;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				OTHER_LDFLAGS = (
					"$(inherited)",
					"-ObjC",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.anomaddev.MyTop10;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				ADMOB_APP_ID = "ca-app-pub-3940256099942544~1458002511";
			}};
			name = Debug;
		}};
		{RELEASE_TARGET} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = MyTop10/Resources/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = MyTop10;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				OTHER_LDFLAGS = (
					"$(inherited)",
					"-ObjC",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.anomaddev.MyTop10;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				ADMOB_APP_ID = "ca-app-pub-3940256099942544~1458002511";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject "MyTop10" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{DEBUG_PROJECT} /* Debug */,
				{RELEASE_PROJECT} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "MyTop10" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{DEBUG_TARGET} /* Debug */,
				{RELEASE_TARGET} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		{FIREBASE_PKG} /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/firebase/firebase-ios-sdk";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 11.0.0;
			}};
		}};
		{SUPABASE_PKG} /* XCRemoteSwiftPackageReference "supabase-swift" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/supabase/supabase-swift";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 2.0.0;
			}};
		}};
		{ADS_PKG} /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/googleads/swift-package-manager-google-mobile-ads";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 12.0.0;
			}};
		}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{FIREBASE_AUTH_PROD} /* FirebaseAuth */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {FIREBASE_PKG} /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
			productName = FirebaseAuth;
		}};
		{FIREBASE_CORE_PROD} /* FirebaseCore */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {FIREBASE_PKG} /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
			productName = FirebaseCore;
		}};
		{SUPABASE_PROD} /* Supabase */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {SUPABASE_PKG} /* XCRemoteSwiftPackageReference "supabase-swift" */;
			productName = Supabase;
		}};
		{ADS_PROD} /* GoogleMobileAds */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {ADS_PKG} /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */;
			productName = GoogleMobileAds;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {PROJECT_ID} /* Project object */;
}}
"""

(PROJ / "project.pbxproj").write_text(pbx)
print(f"Wrote {PROJ / 'project.pbxproj'} with {len(swift_files)} Swift files")
