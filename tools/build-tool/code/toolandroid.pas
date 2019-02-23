{
  Copyright 2014-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Compiling, packaging, installing, running on Android. }
unit ToolAndroid;

interface

uses Classes,
  CastleUtils, CastleStringUtils,
  ToolUtils, ToolArchitectures, ToolCompile, ToolProject;

{ Compile (for all possible Android CPUs) Android unit or library.
  When Project <> nil, we assume we compile libraries (one of more .so files),
  and their final names must match Project.AndroidLibraryFile(CPU). }
procedure CompileAndroid(const Project: TCastleProject;
  const Mode: TCompilationMode; const WorkingDirectory, CompileFile: string;
  const SearchPaths, LibraryPaths, ExtraOptions: TStrings);

{ Android CPU values supported by the current compiler. }
function DetectAndroidCPUS: TCPUS;

{ Convert CPU to an architecture name understood by Android,
  see TARGET_ARCH_ABI at https://developer.android.com/ndk/guides/android_mk . }
function CPUToAndroidArchitecture(const CPU: TCPU): String;

procedure PackageAndroid(const Project: TCastleProject;
  const OS: TOS; const CPUS: TCPUS; const SuggestedPackageMode: TCompilationMode;
  const Files: TCastleStringList);

procedure InstallAndroid(const Name, QualifiedName, OutputPath: string);

procedure RunAndroid(const Project: TCastleProject);

implementation

uses SysUtils, DOM, XMLWrite,
  CastleURIUtils, CastleXMLUtils, CastleLog, CastleFilesUtils, CastleImages,
  ToolEmbeddedImages, ToolFPCVersion;

var
  DetectAndroidCPUSCached: TCPUS;

function DetectAndroidCPUS: TCPUS;
begin
  if DetectAndroidCPUSCached = [] then
  begin
    DetectAndroidCPUSCached := [Arm];
    if FPCVersion.AtLeast(3, 3, 1) then
      Include(DetectAndroidCPUSCached, Aarch64)
    else
      WritelnWarning('FPC version ' + FPCVersion.ToString + ' does not support compiling for 64-bit Android (Aarch64). Resulting APK will only support 32-bit Android devices.');
  end;
  Result := DetectAndroidCPUSCached;
end;

procedure CompileAndroid(const Project: TCastleProject;
  const Mode: TCompilationMode; const WorkingDirectory, CompileFile: string;
  const SearchPaths, LibraryPaths, ExtraOptions: TStrings);
var
  CPU: TCPU;
begin
  for CPU in DetectAndroidCPUS do
  begin
    Compile(Android, CPU, { Plugin } false,
      Mode, WorkingDirectory, CompileFile, SearchPaths, LibraryPaths, ExtraOptions);
    if Project <> nil then
    begin
      CheckRenameFile(Project.AndroidLibraryFile(cpuNone), Project.AndroidLibraryFile(CPU));
      Writeln('Compiled library for Android in ', Project.AndroidLibraryFile(CPU, false));
    end;
  end;
end;

const
  PackageModeToName: array [TCompilationMode] of string = (
    'release',
    'release' { no valgrind support for Android },
    'debug');

function CPUToAndroidArchitecture(const CPU: TCPU): String;
begin
  case CPU of
    { The armeabi-v7a is our proper platform, with hard floats.
      See https://developer.android.com/ndk/guides/application_mk.html
      and http://stackoverflow.com/questions/24948008/linking-so-file-within-android-ndk
      and *do not* confuse this with (removed now) armeabi-v7a-hard ABI:
      https://android.googlesource.com/platform/ndk/+show/353e653824b79c43b948429870d0abeedebde386/docs/HardFloatAbi.md
    }
    arm    : Result := 'armeabi-v7a';
    aarch64: Result := 'arm64-v8a';
    i386   : Result := 'x86';
    x86_64 : Result := 'x86_64';
    else raise Exception.CreateFmt('Android does not support CPU "%s"', [CPUToString(CPU)]);
  end;
end;

function Capitalize(const S: string): string;
begin
  Result := S;
  if Result <> '' then
    Result := AnsiUpperCase(Result[1]) + SEnding(Result, 2);
end;

{ Try to find ExeName executable.
  If not found -> exception (if Required) or return '' (if not Required). }
function FinishExeSearch(const ExeName, BundleName, EnvVarName: string;
  const Required: boolean): string;
begin
  { try to find on $PATH }
  Result := FindExe(ExeName);
  { fail if still not found }
  if Required and (Result = '') then
    raise Exception.Create('Cannot find "' + ExeName + '" executable on $PATH, or within $' + EnvVarName + '. Install Android ' + BundleName + ' and make sure that "' + ExeName + '" executable is on $PATH, or that $' + EnvVarName + ' environment variable is set correctly.');
end;

{ Try to find "ndk-build" tool executable.
  If not found -> exception (if Required) or return '' (if not Required). }
function NdkBuildExe(const Required: boolean = true): string;
const
  ExeName = 'ndk-build';
  BundleName = 'NDK';
  EnvVarName = 'ANDROID_NDK_HOME';
var
  Env: string;
begin
  Result := '';
  { try to find in $ANDROID_NDK_HOME }
  Env := GetEnvironmentVariable(EnvVarName);
  if Env <> '' then
  begin
    Result := AddExeExtension(InclPathDelim(Env) + ExeName);
    if not FileExists(Result) then
      Result := '';
  end;
  { try to find in $ANDROID_HOME }
  if Result = '' then
  begin
    Env := GetEnvironmentVariable('ANDROID_HOME');
    if Env <> '' then
    begin
      Result := AddExeExtension(InclPathDelim(Env) + 'ndk-bundle' + PathDelim + ExeName);
      if not FileExists(Result) then
        Result := '';
    end;
  end;
  { try to find on $PATH }
  if Result = '' then
    Result := FinishExeSearch(ExeName, BundleName, EnvVarName, Required);
end;

{ Try to find "adb" tool executable.
  If not found -> exception (if Required) or return '' (if not Required). }
function AdbExe(const Required: boolean = true): string;
const
  ExeName = 'adb';
  BundleName = 'SDK';
  EnvVarName = 'ANDROID_HOME';
var
  Env: string;
begin
  Result := '';
  { try to find in $ANDROID_HOME }
  Env := GetEnvironmentVariable(EnvVarName);
  if Env <> '' then
  begin
    Result := AddExeExtension(InclPathDelim(Env) + 'platform-tools' + PathDelim + ExeName);
    if not FileExists(Result) then
      Result := '';
  end;
  { try to find on $PATH }
  if Result = '' then
    Result := FinishExeSearch(ExeName, BundleName, EnvVarName, Required);
end;

procedure PackageAndroid(const Project: TCastleProject;
  const OS: TOS; const CPUS: TCPUS; const SuggestedPackageMode: TCompilationMode;
  const Files: TCastleStringList);
var
  AndroidProjectPath: string;

  { Some utility procedures PackageXxx below.
    They work just like Xxx, but target filename should not contain
    prefix AndroidProjectPath. They avoid overwriting stuff
    already existing (in case multiple services
    contain the same path inside), but warn about it. }

  procedure PackageCheckForceDirectories(const Dirs: string);
  begin
    CheckForceDirectories(AndroidProjectPath + Dirs);
  end;

  procedure PackageSaveImage(const Image: TCastleImage; const FileName: string);
  begin
    PackageCheckForceDirectories(ExtractFilePath(FileName));
    if not FileExists(AndroidProjectPath + FileName) then
      SaveImage(Image, FilenameToURISafe(AndroidProjectPath + FileName))
    else
      WritelnWarning('Android', 'Android package file specified by multiple services: ' + FileName);
  end;

  procedure PackageSmartCopyFile(const FileFrom, FileTo: string);
  begin
    PackageCheckForceDirectories(ExtractFilePath(FileTo));
    if not FileExists(AndroidProjectPath + FileTo) then
      SmartCopyFile(FileFrom, AndroidProjectPath + FileTo)
    else
      WritelnWarning('Android', 'Android package file specified by multiple services: ' + FileTo);
  end;

{
  procedure PackageStringToFile(const FileTo, Contents: string);
  begin
    if not FileExists(AndroidProjectPath + FileTo) then
    begin
      PackageCheckForceDirectories(ExtractFilePath(FileTo));
      StringToFile(FileTo, Contents);
    end else
      WritelnWarning('Android package file specified by multiple services: ' + FileTo);
  end;
}

  { Generate files for Android project from templates. }
  procedure GenerateFromTemplates;
  var
    DestinationPath: string;

    procedure ExtractService(const ServiceName: string);
    var
      TemplatePath: string;
    begin
      TemplatePath := 'android/integrated-services/' + ServiceName;
      Project.ExtractTemplate(TemplatePath, DestinationPath);
    end;

  var
    TemplatePath: string;
    I: Integer;
  begin
    { calculate absolute DestinationPath.
      Use CombinePaths, in case AndroidProjectPath is relative to project dir
      (although it's not possible now). }
    DestinationPath := CombinePaths(Project.Path, AndroidProjectPath);

    { add Android project core directory }
    case Project.AndroidProjectType of
      apBase      : TemplatePath := 'android/base/';
      apIntegrated: TemplatePath := 'android/integrated/';
      else raise EInternalError.Create('GenerateFromTemplates:Project.AndroidProjectType unhandled');
    end;
    Project.ExtractTemplate(TemplatePath, DestinationPath);

    if Project.AndroidProjectType = apIntegrated then
    begin
      { add declared services }
      for I := 0 to Project.AndroidServices.Count - 1 do
        ExtractService(Project.AndroidServices[I].Name);

      { add automatic services }
      if (depSound in Project.Dependencies) and
         not Project.AndroidServices.HasService('sound') then
        ExtractService('sound');
      if (depOggVorbis in Project.Dependencies) and
         not Project.AndroidServices.HasService('ogg_vorbis') then
        ExtractService('ogg_vorbis');
      if (depFreeType in Project.Dependencies) and
         not Project.AndroidServices.HasService('freetype') then
        ExtractService('freetype');
    end;
  end;

  procedure GenerateIcons;
  var
    Icon: TCastleImage;

    procedure SaveResized(const Size: Integer; const S: string);
    var
      R: TCastleImage;
      Dir: string;
    begin
      R := Icon.MakeResized(Size, Size, BestInterpolation);
      try
        Dir := 'app' + PathDelim + 'src' + PathDelim + 'main' + PathDelim +
               'res' + PathDelim + 'mipmap-' + S + 'dpi';
        PackageSaveImage(R, Dir + PathDelim + 'ic_launcher.png');
      finally FreeAndNil(R) end;
    end;

  begin
    Icon := Project.Icons.FindReadable;
    if Icon = nil then
    begin
      WritelnWarning('Icon', 'No icon in a format readable by our engine (for example, png or jpg) is specified in CastleEngineManifest.xml. Using default icon.');
      Icon := DefaultIcon;
    end;
    try
      SaveResized(48, 'm');
      SaveResized(72, 'h');
      SaveResized(96, 'xh');
      SaveResized(144, 'xxh');
    finally
      if Icon = DefaultIcon then
        Icon := nil else
        FreeAndNil(Icon);
    end;
  end;

  procedure GenerateAssets;
  var
    I: Integer;
    FileFrom, FileTo: string;
  begin
    for I := 0 to Files.Count - 1 do
    begin
      FileFrom := Project.DataPath + Files[I];
      FileTo := 'app' + PathDelim + 'src' + PathDelim + 'main' + PathDelim +
                'assets' + PathDelim + Files[I];
      PackageSmartCopyFile(FileFrom, FileTo);
      if Verbose then
        Writeln('Packaging data file: ' + Files[I]);
    end;
  end;

  procedure GenerateLocalization;
  var
    LocalizedAppName: TLocalizedAppName;
    Doc: TXMLDocument;
    RootNode, StringNode: TDOMNode;
    I: TXMLElementIterator;
    Language, StringsPath: String;
  begin
    if not Assigned(Project.ListLocalizedAppName) then Exit;

    //Change default app_name to translatable:
    StringsPath := AndroidProjectPath + 'app' + PathDelim +'src' + PathDelim + 'main' + PathDelim + 'res' + PathDelim + 'values' + PathDelim + 'strings.xml';
    URLReadXML(Doc, StringsPath);
    try
      I := Doc.DocumentElement.ChildrenIterator;
      try
        while I.GetNext do
          if (I.Current.TagName = 'string') and (I.Current.AttributeString('name') = 'app_name') then
          begin
            I.Current.AttributeSet('translatable', 'true');
            Break; //There can only be one string 'app_name', so we don't need to continue the loop.
          end;
      finally
        I.Free;
      end;

      WriteXMLFile(Doc, StringsPath);
    finally
      Doc.Free;
    end;

    //Write strings for every chosen language:
    for LocalizedAppName in Project.ListLocalizedAppName do
    begin
      Doc := TXMLDocument.Create;
      try
        RootNode := Doc.CreateElement('resources');
        Doc.Appendchild(RootNode);
        RootNode:= Doc.DocumentElement;

        StringNode := Doc.CreateElement('string');
        TDOMElement(StringNode).AttributeSet('name', 'app_name');
        StringNode.AppendChild(Doc.CreateTextNode(UTF8Decode(LocalizedAppName.AppName)));
        RootNode.AppendChild(StringNode);

        if LocalizedAppName.Language = 'default' then
          Language := ''
        else
          Language := '-' + LocalizedAppName.Language;

        StringsPath := AndroidProjectPath + 'app' + PathDelim +'src' + PathDelim + 'main' + PathDelim + 'res' + PathDelim +
                                            'values' + Language + PathDelim + 'strings.xml';

        CheckForceDirectories(ExtractFilePath(StringsPath));
        WriteXMLFile(Doc, StringsPath);
      finally
        Doc.Free;
      end;
    end;
  end;

  procedure GenerateLibrary;
  var
    CPU: TCPU;
    JniPath, LibraryWithoutCPU, LibraryFileName: String;
  begin
    JniPath := 'app' + PathDelim + 'src' + PathDelim + 'main' + PathDelim +
      { Place precompiled libs in jni/ , ndk-build will find them there. }
      'jni' + PathDelim;
    LibraryWithoutCPU := ExtractFileName(Project.AndroidLibraryFile(cpuNone));

    for CPU in CPUS do
    begin
      LibraryFileName := Project.AndroidLibraryFile(CPU);
      PackageSmartCopyFile(LibraryFileName,
        JniPath + CPUToAndroidArchitecture(CPU) + PathDelim + LibraryWithoutCPU);
    end;
  end;

var
  KeyStore, KeyAlias, KeyStorePassword, KeyAliasPassword: string;

  procedure CalculateSigningProperties(var PackageMode: TCompilationMode);
  const
    WWW = 'https://github.com/castle-engine/castle-engine/wiki/Android';

    procedure LoadSigningProperties(const FileName: string);
    var
      S: TStringList;
    begin
      S := TStringList.Create;
      try
        S.LoadFromFile(FileName);
        if (PackageMode <> cmDebug) and (
            (S.IndexOfName('key.store') = -1) or
            (S.IndexOfName('key.alias') = -1) or
            (S.IndexOfName('key.store.password') = -1) or
            (S.IndexOfName('key.alias.password') = -1)) then
        begin
          WritelnWarning('Android', 'Key information (key.store, key.alias, key.store.password, key.alias.password) to sign release Android package not found inside "' + FileName + '" file. See ' + WWW + ' for documentation how to create and use keys to sign release Android apk. Falling back to creating debug apk.');
          PackageMode := cmDebug;
        end;
        if PackageMode <> cmDebug then
        begin
          KeyStore := S.Values['key.store'];
          KeyAlias := S.Values['key.alias'];
          KeyStorePassword := S.Values['key.store.password'];
          KeyAliasPassword := S.Values['key.alias.password'];

          (*
          Project.AndroidSigningConfig :=
            'signingConfigs {' + NL +
            '    release {' + NL +
            '        storeFile file("' + KeyStore + '")' + NL +
            '        storePassword "' + KeyStorePassword + '"' + NL +
            '        keyAlias "' + KeyAlias + '"' + NL +
            '        keyPassword "' + KeyAliasPassword + '"' + NL +
            '    }' + NL +
            '}' + NL;
          Project.AndroidSigningConfigDeclare := 'signingConfig signingConfigs.release';

          This fails with gradle error
          (as of 'com.android.tools.build:gradle-experimental:0.7.0' ; did not try with later versions)

            * Where:
            Build file '/tmp/castle-engine157085/app/build.gradle' line: 26
            * What went wrong:
            A problem occurred configuring project ':app'.
            > Exception thrown while executing model rule: android { ... } @ app/build.gradle line 4, column 5 > named(release)
               > Attempt to read a write only view of model of type 'org.gradle.model.ModelMap<com.android.build.gradle.managed.BuildType>' given to rule 'android { ... } @ app/build.gradle line 4, column 5'

          See
          https://code.google.com/p/android/issues/detail?id=182249
          http://stackoverflow.com/questions/32109501/adding-release-keys-in-the-experimental-gradle-plugin-for-android

          We use simpler solution now, from the bottom of
          https://plus.googleapis.com/+JoakimEngstr%C3%B6mJ/posts/NY3JUkz5dPP
          See also
          http://www.tinmith.net/wayne/blog/2014/08/gradle-sign-command-line.htm
          *)
        end;
      finally FreeAndNil(S) end;
    end;

  const
    SourceAntPropertiesOld = 'AndroidAntProperties.txt';
    SourceAntProperties = 'AndroidSigningProperties.txt';
  begin
    KeyStore := '';
    KeyAlias := '';
    KeyStorePassword := '';
    KeyAliasPassword := '';
    if FileExists(Project.Path + SourceAntProperties) then
    begin
      LoadSigningProperties(Project.Path + SourceAntProperties);
    end else
    if FileExists(Project.Path + SourceAntPropertiesOld) then
    begin
      LoadSigningProperties(Project.Path + SourceAntPropertiesOld);
      WritelnWarning('Deprecated', 'Using deprecated configuration file name "' + SourceAntPropertiesOld + '". Rename it to "' + SourceAntProperties + '".');
    end else
    if PackageMode <> cmDebug then
    begin
      WritelnWarning('Android', 'Information about the keys to sign release Android package not found, because "' + SourceAntProperties + '" file does not exist. See ' + WWW + ' for documentation how to create and use keys to sign release Android apk. Falling back to creating debug apk.');
      PackageMode := cmDebug;
    end;
  end;

  { Run "ndk-build", this moves our .so to the final location in jniLibs,
    also preserving our debug symbols, so that ndk-gdb remains useful.

    TODO: Calling ndk-build directly is a hack,
    since Gradle will later call ndk-build anyway.
    But without calling ndk-build directly
    it seems impossible to have debug symbols to our prebuilt
    library correctly preserced, such that ndk-gdb works and sees our symbols.
  }
  procedure RunNdkBuild;
  begin
    { Place precompiled .so files in jniLibs/ to make them picked up by Gradle.
      See http://stackoverflow.com/questions/27532062/include-pre-compiled-static-library-using-ndk
      http://stackoverflow.com/a/28430178

      Possibly we could also let the ndk-build to place them in libs/,
      as it does by default.

      We know we should not let them be only in jni/ subdir,
      as they would not be picked by Gradle from there. But that's
      what ndk-build does: it copies them from jni/ to another directory. }

    RunCommandSimple(AndroidProjectPath + 'app' + PathDelim + 'src' + PathDelim + 'main',
      NdkBuildExe, ['--silent', 'NDK_LIBS_OUT=./jniLibs']);
  end;

  { Run Gradle to actually build the final apk. }
  procedure RunGradle(const PackageMode: TCompilationMode);
  var
    Args: TCastleStringList;
  begin
    Args := TCastleStringList.Create;
    try
      Args.Add('assemble' + Capitalize(PackageModeToName[PackageMode]));
      if not Verbose then
        Args.Add('--quiet');
      if PackageMode <> cmDebug then
      begin
        Args.Add('-Pandroid.injected.signing.store.file=' + KeyStore);
        Args.Add('-Pandroid.injected.signing.store.password=' + KeyStorePassword);
        Args.Add('-Pandroid.injected.signing.key.alias=' + KeyAlias);
        Args.Add('-Pandroid.injected.signing.key.password=' + KeyAliasPassword);
      end;
      {$ifdef MSWINDOWS}
      try
        RunCommandSimple(AndroidProjectPath, AndroidProjectPath + 'gradlew.bat', Args.ToArray);
      finally
        { Gradle deamon is automatically initialized since Gradle version 3.0
          (see https://docs.gradle.org/current/userguide/gradle_daemon.html)
          but it prevents removing the castle-engine-output/android/project/ .
          E.g. you cannot run "castle-engine package --os=android --cpu=arm"
          again in the same directory, because it cannot remove the
          "castle-engine-output/android/project/" at the beginning.

          It seems the current directory of Java (Gradle) process is inside
          castle-engine-output/android/project/, and Windows doesn't allow to remove such
          directory. Doing "rm -Rf castle-engine-output/android/project/" (rm.exe from Cygwin)
          also fails with

            rm: cannot remove 'castle-engine-output/android/project/': Device or resource busy

          This may be related to
          https://discuss.gradle.org/t/the-gradle-daemon-prevents-a-clean/2473/13

          The solution for now is to kill the daemon afterwards. }
        RunCommandSimple(AndroidProjectPath, AndroidProjectPath + 'gradlew.bat', ['--stop']);
      end;

      {$else}
      if FileExists(AndroidProjectPath + 'gradlew') then
      begin
        Args.Insert(0, './gradlew');
        RunCommandSimple(AndroidProjectPath, 'bash', Args.ToArray);
      end else
      begin
        Writeln('Local Gradle wrapper ("gradlew") not found, so we will call the Gradle on $PATH.');
        Writeln('Make sure you have installed Gradle (e.g. from the Debian "gradle" package), in a version compatible with the Android Gradle plugin (see https://developer.android.com/studio/releases/gradle-plugin.html#updating-gradle ).');
        RunCommandSimple(AndroidProjectPath, 'gradle', Args.ToArray);
      end;
      {$endif}
    finally FreeAndNil(Args) end;
  end;

var
  ApkName: string;
  PackageMode: TCompilationMode;
begin
  { calculate clean AndroidProjectPath }
  AndroidProjectPath := TempOutputPath(Project.Path) +
    'android' + PathDelim + 'project' + PathDelim;
  if DirectoryExists(AndroidProjectPath) then
    RemoveNonEmptyDir(AndroidProjectPath);

  PackageMode := SuggestedPackageMode;

  CalculateSigningProperties(PackageMode);

  GenerateFromTemplates;
  GenerateIcons;
  GenerateAssets;
  GenerateLocalization;
  GenerateLibrary;
  RunNdkBuild;
  RunGradle(PackageMode);

  ApkName := Project.Name + '-' + PackageModeToName[PackageMode] + '.apk';
  CheckRenameFile(AndroidProjectPath + 'app' + PathDelim +
    'build' +  PathDelim +
    'outputs' + PathDelim +
    'apk' + PathDelim +
    PackageModeToName[PackageMode] + PathDelim +
    'app-' + PackageModeToName[PackageMode] + '.apk',
    Project.OutputPath + ApkName);

  Writeln('Build ' + ApkName);
end;

procedure InstallAndroid(const Name, QualifiedName, OutputPath: string);
var
  ApkDebugName, ApkReleaseName, ApkName: string;
begin
  ApkReleaseName := CombinePaths(OutputPath, Name + '-' + PackageModeToName[cmRelease] + '.apk');
  ApkDebugName   := CombinePaths(OutputPath, Name + '-' + PackageModeToName[cmDebug  ] + '.apk');
  if FileExists(ApkDebugName) and FileExists(ApkReleaseName) then
    raise Exception.CreateFmt('Both debug and release apk files exist in this directory: "%s" and "%s". We do not know which to install --- resigning. Simply rename or delete one of the apk files.',
      [ApkDebugName, ApkReleaseName]);
  if FileExists(ApkDebugName) then
    ApkName := ApkDebugName else
  if FileExists(ApkReleaseName) then
    ApkName := ApkReleaseName else
    raise Exception.CreateFmt('No Android apk found in this directory: "%s" or "%s"',
      [ApkDebugName, ApkReleaseName]);

  { Uninstall and then install, instead of calling "install -r",
    to avoid failures because apk signed with different keys (debug vs release). }

  Writeln('Reinstalling application identified as "' + QualifiedName + '".');
  Writeln('If this fails, an often cause is that a previous development version of the application, signed with a different key, remains on the device. In this case uninstall it first (note that it will clear your UserConfig data, unless you use -k) by "adb uninstall ' + QualifiedName + '"');
  RunCommandSimple(AdbExe, ['install', '-r', ApkName]);
  Writeln('Install successful.');
end;

procedure RunAndroid(const Project: TCastleProject);
var
  ActivityName, LogTag: string;
begin
  if Project.AndroidProjectType = apBase then
    ActivityName := 'android.app.NativeActivity'
  else
    ActivityName := 'net.sourceforge.castleengine.MainActivity';
  RunCommandSimple(AdbExe, ['shell', 'am', 'start',
    '-a', 'android.intent.action.MAIN',
    '-n', Project.QualifiedName + '/' + ActivityName ]);
  Writeln('Run successful.');

  LogTag := Copy(Project.Name, 1, MaxAndroidTagLength);

  Writeln('Running "adb logcat -s ' + LogTag + ':V".');
  Writeln('We are assuming that your ApplicationName is "' + Project.Name + '".');
  Writeln('Break this process with Ctrl+C.');

  { run through ExecuteProcess, because we don't want to capture output,
    we want to immediately pass it to user }
  ExecuteProcess(AdbExe, ['logcat', '-s', LogTag + ':V']);
end;

end.
