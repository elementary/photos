
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.h)
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake ${CONFIG_FILE})

vala_precompile (PLUGIN_VALA_C ${EXEC_NAME}-plugin
    plugins/PublishingInterfaces.vala
    plugins/SpitInterfaces.vala
    plugins/TransitionsInterfaces.vala
GENERATE_VAPI
    ${CMAKE_PROJECT_NAME}
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)


vala_precompile (VALA_C ${EXEC_NAME}
    AppDirs.vala
    Application.vala
    AppWindow.vala
    BatchImport.vala
    Box.vala
    CheckerboardPage.vala
    CollectionPage.vala
    ColorTransformation.vala
    CommandManager.vala
    Commands.vala
    CustomComponents.vala
    DesktopIntegration.vala
    Dimensions.vala
    DirectoryMonitor.vala
    Event.vala
    Exporter.vala
    FullScreenWindow.vala
    LibraryFiles.vala
    LibraryMonitor.vala
    main.vala
    MediaDataRepresentation.vala
    MediaInterfaces.vala
    MediaMetadata.vala
    MediaMonitor.vala
    MediaPage.vala
    MediaViewTracker.vala
    MetadataWriter.vala
    Orientation.vala
    Page.vala
    PageWindow.vala
    PhotoMonitor.vala
    PhotoPage.vala
    Photo.vala
    PixbufCache.vala
    Printing.vala
    Resources.vala
    Screensaver.vala
    SearchFilter.vala
    SinglePhotoPage.vala
    SlideshowPage.vala
    SortedList.vala
    Tag.vala
    ThumbnailCache.vala
    Thumbnail.vala
    TimedQueue.vala
    Tombstone.vala
    UnityProgressBar.vala
    Upgrades.vala
    VideoMetadata.vala
    VideoMonitor.vala
    VideoSupport.vala

    camera/Branch.vala
    camera/CameraTable.vala
    camera/Camera.vala
    camera/GPhoto.vala
    camera/ImportPage.vala

    Checkerboard/CheckerboardItem.vala
    Checkerboard/CheckerboardItemText.vala
    Checkerboard/CheckerboardLayout.vala

    Dialogs/AdjustDateTimeDialog.vala
    Dialogs/Dialogs.vala
    Dialogs/ExportDialog.vala
    Dialogs/PreferencesDialog.vala
    Dialogs/ProgressDialog.vala
    Dialogs/TextEntryDialog.vala

    config/ConfigurationInterfaces.vala
    config/Config.vala
    config/GSettingsEngine.vala

    core/Alteration.vala
    core/ContainerSourceCollection.vala
    core/Core.vala
    core/DatabaseSourceCollection.vala
    core/DataCollection.vala
    core/DataObject.vala
    core/DataSet.vala
    core/DataSourceTypes.vala
    core/DataSource.vala
    core/DataViewTypes.vala
    core/DataView.vala
    core/SourceCollection.vala
    core/SourceHoldingTank.vala
    core/SourceInterfaces.vala
    core/Tracker.vala
    core/util.vala
    core/ViewCollection.vala

    db/DatabaseTable.vala
    db/Db.vala
    db/EventTable.vala
    db/PhotoTable.vala
    db/SavedSearchDBTable.vala
    db/TagTable.vala
    db/TombstoneTable.vala
    db/VersionTable.vala
    db/VideoTable.vala

    direct/DirectPhotoPage.vala
    direct/DirectPhoto.vala
    direct/Direct.vala
    direct/DirectView.vala
    direct/DirectWindow.vala

    editing_tools/EditingTools.vala
    editing_tools/StraightenTool.vala
    editing_tools/RedEyeTool.vala
    editing_tools/CropTool.vala
    editing_tools/AdjustTool.vala

    events/Branch.vala
    events/EventDirectoryItem.vala
    events/EventPage.vala
    events/EventsDirectoryPage.vala
    events/Events.vala

    library/Branch.vala
    library/FlaggedPage.vala
    library/FlaggedSidebarEntry.vala
    library/ImportQueuePage.vala
    library/ImportQueueSidebarEntry.vala
    library/LastImportPage.vala
    library/LastImportSidebarEntry.vala
    library/Library.vala
    library/LibraryWindow.vala
    library/OfflinePage.vala
    library/OfflineSidebarEntry.vala
    library/PhotosPage.vala
    library/RawsPage.vala
    library/TopDisplay.vala
    library/TrashPage.vala
    library/TrashSidebarEntry.vala
    library/VideosPage.vala

    photos/BmpSupport.vala
    photos/GdkSupport.vala
    photos/GifSupport.vala
    photos/GRaw.vala
    photos/JfifSupport.vala
    photos/PhotoFileAdapter.vala
    photos/PhotoFileFormat.vala
    photos/PhotoFileSniffer.vala
    photos/PhotoMetadata.vala
    photos/Photos.vala
    photos/PngSupport.vala
    photos/RawSupport.vala
    photos/TiffSupport.vala
    photos/WebPSupport.vala

    plugins/Plugins.vala
    plugins/StandardHostInterface.vala
    plugins/ManifestWidget.vala

    publishing/APIGlue.vala
    publishing/PublishingPluginHost.vala
    publishing/PublishingUI.vala
    publishing/Publishing.vala

    searches/Branch.vala
    searches/SavedSearchDialog.vala
    searches/SavedSearchPage.vala
    searches/SearchBoolean.vala
    searches/Searches.vala

    sidebar/Branch.vala
    sidebar/common.vala
    sidebar/Entry.vala
    sidebar/Sidebar.vala
    sidebar/Tree.vala
    sidebar/EditableTitle.vala

    sidebar/metadata/BasicProperties.vala
    sidebar/metadata/ExtendedProperties.vala
    sidebar/metadata/LibraryProperties.vala
    sidebar/metadata/MetadataSidebar.vala
    sidebar/metadata/Properties.vala

    slideshow/Slideshow.vala
    slideshow/TransitionEffects.vala

    tags/Branch.vala
    tags/HierarchicalTagIndex.vala
    tags/HierarchicalTagUtilities.vala
    tags/TagPage.vala
    tags/Tags.vala

    threads/BackgroundJob.vala
    threads/Semaphore.vala
    threads/Workers.vala

    unit/Unit.vala

    util/DragAndDropHandler.vala
    util/file.vala
    util/image.vala
    util/KeyValueMap.vala
    util/misc.vala
    util/string.vala
    util/system.vala
    util/ui.vala
    util/Util.vala

    Widgets/ContractMenuItem.vala
    Widgets/TransitionEffectSelector.vala
    Widgets/SliderAssembly.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/config.vapi
    ${CMAKE_BINARY_DIR}/src/${CMAKE_PROJECT_NAME}.vapi
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_ICONS SOURCE ../data/icons/icons.gresource.xml)
glib_compile_resources (GLIB_RESOURCE SOURCE ../data/io.elementary.photos.gresource.xml)

include_directories (${CMAKE_SOURCE_DIR}/vapi)
add_executable (${EXEC_NAME} ${VALA_C} ${PLUGIN_VALA_C} ${CONFIG_FILE} ${GLIB_RESOURCES_ICONS} ${GLIB_RESOURCE})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

