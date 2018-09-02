library_files = files(
    'plugins/PublishingInterfaces.vala',
    'plugins/SpitInterfaces.vala',
    'plugins/TransitionsInterfaces.vala'
)

conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('_VERSION', meson.project_version())
conf_data.set_quoted('_PREFIX', get_option('prefix'))
conf_data.set_quoted('_LIB', join_paths(get_option('prefix'), get_option('libdir')))
conf_data.set_quoted('_LIBEXECDIR', libexecdir)
config_header = configure_file(
    output : 'config.h',
    configuration : conf_data
)

photos_files = files(
    'AppDirs.vala',
    'Application.vala',
    'AppWindow.vala',
    'BatchImport.vala',
    'Box.vala',
    'CollectionPage.vala',
    'CollectionViewManager.vala',
    'ColorTransformation.vala',
    'CommandManager.vala',
    'Commands.vala',
    'CustomComponents.vala',
    'DesktopIntegration.vala',
    'Dimensions.vala',
    'DirectoryMonitor.vala',
    'EditingHostPage.vala',
    'Event.vala',
    'Exporter.vala',
    'FullScreenWindow.vala',
    'LibraryFiles.vala',
    'LibraryMonitor.vala',
    'LibraryPhotoPage.vala',
    'main.vala',
    'MediaDataRepresentation.vala',
    'MediaInterfaces.vala',
    'MediaMetadata.vala',
    'MediaMonitor.vala',
    'MediaPage.vala',
    'MediaViewTracker.vala',
    'MetadataWriter.vala',
    'Orientation.vala',
    'Page.vala',
    'PageWindow.vala',
    'PhotoMonitor.vala',
    'Photo.vala',
    'PixbufCache.vala',
    'Printing.vala',
    'Resources.vala',
    'SearchFilter.vala',
    'SinglePhotoPage.vala',
    'SlideshowPage.vala',
    'SortedList.vala',
    'Tag.vala',
    'ThumbnailCache.vala',
    'Thumbnail.vala',
    'TimedQueue.vala',
    'Tombstone.vala',
    'UnityProgressBar.vala',
    'Upgrades.vala',
    'VideoMetadata.vala',
    'VideoMonitor.vala',
    'VideoSupport.vala',
    'ZoomBuffer.vala',

    'camera/Branch.vala',
    'camera/CameraTable.vala',
    'camera/GPhoto.vala',
    'camera/ImportPage.vala',

    'Checkerboard/CheckerboardPage.vala',
    'Checkerboard/CheckerboardItem.vala',
    'Checkerboard/CheckerboardItemText.vala',
    'Checkerboard/CheckerboardLayout.vala',

    'Dialogs/AdjustDateTimeDialog.vala',
    'Dialogs/Dialogs.vala',
    'Dialogs/ExportDialog.vala',
    'Dialogs/PreferencesDialog.vala',
    'Dialogs/ProgressDialog.vala',
    'Dialogs/TextEntryDialog.vala',

    'config/ConfigurationInterfaces.vala',
    'config/Config.vala',
    'config/GSettingsEngine.vala',

    'core/AbstractViewManager.vala',
    'core/Alteration.vala',
    'core/ContainerSourceCollection.vala',
    'core/DatabaseSourceCollection.vala',
    'core/DataCollection.vala',
    'core/DataObject.vala',
    'core/DataSet.vala',
    'core/DataSourceTypes.vala',
    'core/DataSource.vala',
    'core/DataViewTypes.vala',
    'core/DataView.vala',
    'core/SourceCollection.vala',
    'core/SourceHoldingTank.vala',
    'core/SourceInterfaces.vala',
    'core/Tracker.vala',
    'core/util.vala',
    'core/ViewCollection.vala',

    'db/DatabaseTable.vala',
    'db/Db.vala',
    'db/EventTable.vala',
    'db/PhotoTable.vala',
    'db/SavedSearchDBTable.vala',
    'db/TagTable.vala',
    'db/TombstoneTable.vala',
    'db/VersionTable.vala',
    'db/VideoTable.vala',

    'direct/DirectPhotoPage.vala',
    'direct/DirectPhoto.vala',
    'direct/Direct.vala',
    'direct/DirectView.vala',
    'direct/DirectWindow.vala',

    'editing_tools/EditingTools.vala',
    'editing_tools/StraightenTool.vala',
    'editing_tools/RedEyeTool.vala',
    'editing_tools/CropTool.vala',
    'editing_tools/AdjustTool.vala',

    'events/Branch.vala',
    'events/EventDirectoryItem.vala',
    'events/EventPage.vala',
    'events/EventsDirectoryPage.vala',

    'library/Branch.vala',
    'library/FlaggedPage.vala',
    'library/FlaggedSidebarEntry.vala',
    'library/ImportQueuePage.vala',
    'library/ImportQueueSidebarEntry.vala',
    'library/LastImportPage.vala',
    'library/LastImportSidebarEntry.vala',
    'library/Library.vala',
    'library/LibraryWindow.vala',
    'library/OfflinePage.vala',
    'library/OfflineSidebarEntry.vala',
    'library/PhotosPage.vala',
    'library/RawsPage.vala',
    'library/TopDisplay.vala',
    'library/TrashPage.vala',
    'library/TrashSidebarEntry.vala',
    'library/VideosPage.vala',

    'photos/BmpSupport.vala',
    'photos/GdkSupport.vala',
    'photos/GifSupport.vala',
    'photos/GRaw.vala',
    'photos/JfifSupport.vala',
    'photos/PhotoFileAdapter.vala',
    'photos/PhotoFileFormat.vala',
    'photos/PhotoFileSniffer.vala',
    'photos/PhotoMetadata.vala',
    'photos/PngSupport.vala',
    'photos/RawSupport.vala',
    'photos/TiffSupport.vala',
    'photos/WebPSupport.vala',

    'plugins/Plugins.vala',
    'plugins/StandardHostInterface.vala',
    'plugins/ManifestWidget.vala',

    'publishing/APIGlue.vala',
    'publishing/PublishingPluginHost.vala',
    'publishing/PublishingUI.vala',
    'publishing/Publishing.vala',

    'searches/Branch.vala',
    'searches/SavedSearchDialog.vala',
    'searches/SavedSearchPage.vala',
    'searches/SearchBoolean.vala',

    'sidebar/Branch.vala',
    'sidebar/common.vala',
    'sidebar/Entry.vala',
    'sidebar/Tree.vala',
    'sidebar/EditableTitle.vala',

    'sidebar/metadata/BasicProperties.vala',
    'sidebar/metadata/ExtendedProperties.vala',
    'sidebar/metadata/LibraryProperties.vala',
    'sidebar/metadata/MetadataSidebar.vala',
    'sidebar/metadata/Properties.vala',

    'slideshow/Slideshow.vala',
    'slideshow/TransitionEffects.vala',

    'tags/Branch.vala',
    'tags/HierarchicalTagIndex.vala',
    'tags/HierarchicalTagUtilities.vala',
    'tags/TagPage.vala',

    'threads/BackgroundJob.vala',
    'threads/Semaphore.vala',
    'threads/Workers.vala',

    'util/DragAndDropHandler.vala',
    'util/file.vala',
    'util/image.vala',
    'util/KeyValueMap.vala',
    'util/misc.vala',
    'util/string.vala',
    'util/system.vala',
    'util/ui.vala',
    'util/Util.vala',

    'Widgets/TransitionEffectSelector.vala',
    'Widgets/SliderAssembly.vala',
    'Widgets/ContractMenuItem.vala',
    'Widgets/CustomPrintTab.vala'
)

photos_exe = executable(
    meson.project_name(),
    photos_files,
    library_files,
    config_header,
    icons_gresource,
    global_gresource,
    dependencies: dependencies,
    include_directories: vapi_include,
    export_dynamic: true,
    install: true
)

# We declare a dependency to be used by plugins
photos_dep = declare_dependency(
    dependencies: dependencies,
    include_directories: [vapi_include, include_directories('.')],
    link_with: photos_exe
)
