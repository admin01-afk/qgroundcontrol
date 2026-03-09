#include "QGCCorePlugin.h"
#include "QGCLogging.h"
#include "AppSettings.h"
#include "MavlinkSettings.h"
#include "FactMetaData.h"
#ifdef QGC_GST_STREAMING
#include "GStreamer.h"
#endif
#include "HorizontalFactValueGrid.h"
#include "InstrumentValueData.h"
#include "JoystickManager.h"
#include "MAVLinkLib.h"
#include "QGCLoggingCategory.h"
#include "QGCOptions.h"
#include "QmlComponentInfo.h"
#include "QmlObjectListModel.h"
#ifdef QGC_QT_STREAMING
#include "QtMultimediaReceiver.h"
#endif
#include "SettingsManager.h"
#include "VideoReceiver.h"

#ifdef QGC_CUSTOM_BUILD
#include CUSTOMHEADER
#endif

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/qqml.h>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlContext>
#include <QtQuick/QQuickItem>

QGC_LOGGING_CATEGORY(QGCCorePluginLog, "API.QGCCorePlugin");

#ifndef QGC_CUSTOM_BUILD
Q_APPLICATION_STATIC(QGCCorePlugin, _qgcCorePluginInstance);
#endif

QGCCorePlugin::QGCCorePlugin(QObject *parent)
    : QObject(parent)
    , _defaultOptions(new QGCOptions(this))
    , _emptyCustomMapItems(new QmlObjectListModel(this))
{
    qCDebug(QGCCorePluginLog) << this;
}

QGCCorePlugin::~QGCCorePlugin()
{
    qCDebug(QGCCorePluginLog) << this;
}

QGCCorePlugin *QGCCorePlugin::instance()
{
#ifndef QGC_CUSTOM_BUILD
    return _qgcCorePluginInstance();
#else
    return CUSTOMCLASS::instance();
#endif
}

const QVariantList &QGCCorePlugin::analyzePages()
{
    static const QVariantList analyzeList = {
        QVariant::fromValue(new QmlComponentInfo(
            tr("Log Download"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/LogDownloadPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/LogDownloadIcon.svg")))),
        QVariant::fromValue(new QmlComponentInfo(
            tr("GeoTag Images"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/GeoTag/GeoTagPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/GeoTag/GeoTagIcon.svg")))),
        QVariant::fromValue(new QmlComponentInfo(
            tr("MAVLink Console"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/MAVLinkConsolePage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/MAVLinkConsoleIcon.svg")))),
#ifndef QGC_DISABLE_MAVLINK_INSPECTOR
        QVariant::fromValue(new QmlComponentInfo(
            tr("MAVLink Inspector"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/MAVLinkInspectorPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/MAVLinkInspector.svg")))),
#endif
        QVariant::fromValue(new QmlComponentInfo(
            tr("Vibration"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/VibrationPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/VibrationPageIcon")))),
    };

    return analyzeList;
}

QGCOptions *QGCCorePlugin::options()
{
    return _defaultOptions;
}

const QmlObjectListModel *QGCCorePlugin::customMapItems()
{
    return _emptyCustomMapItems;
}

void QGCCorePlugin::adjustSettingMetaData(const QString &settingsGroup, FactMetaData &metaData, bool &visible)
{
#ifdef Q_OS_ANDROID
    Q_UNUSED(visible);
#endif

    if (settingsGroup == AppSettings::settingsGroup) {
        if (metaData.name() == AppSettings::indoorPaletteName) {
            QVariant outdoorPalette;
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
            outdoorPalette = 0;
#else
            outdoorPalette = 1;
#endif
            metaData.setRawDefaultValue(outdoorPalette);
            return;
        }
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
        else if (metaData.name() == MavlinkSettings::telemetrySaveName) {
            metaData.setRawDefaultValue(false);
            return;
        }
#endif
#ifndef Q_OS_ANDROID
        else if (metaData.name() == AppSettings::androidDontSaveToSDCardName) {
            visible = false;
            return;
        }
#endif
    }
}

QString QGCCorePlugin::showAdvancedUIMessage() const
{
    return tr("WARNING: You are about to enter Advanced Mode. "
              "If used incorrectly, this may cause your vehicle to malfunction thus voiding your warranty. "
              "You should do so only if instructed by customer support. "
              "Are you sure you want to enable Advanced Mode?");
}

void QGCCorePlugin::factValueGridCreateDefaultSettings(FactValueGrid* factValueGrid)
{
    // fontSize=3
    factValueGrid->setFontSize(static_cast<FactValueGrid::FontSize>(3));

    // 4 columns
    (void) factValueGrid->appendColumn(); // col 0
    (void) factValueGrid->appendColumn(); // col 1
    (void) factValueGrid->appendColumn(); // col 2
    (void) factValueGrid->appendColumn(); // col 3

    // grid has 3 rows. appendRow() creates a new row across all columns.
    // Call it twice because the FactValueGrid usually starts with 1 row already after construction.
    factValueGrid->appendRow(); // now at least 2
    factValueGrid->appendRow(); // now at least 3

    // Helper to access a specific cell
    auto columnModel = [&](int colIndex) -> QmlObjectListModel* {
        return factValueGrid->columns()->value<QmlObjectListModel*>(colIndex);
    };

    // --- Column 1 (index 0) ---
    {
        QmlObjectListModel* col = columnModel(0);
        int rowIndex = 0;

        InstrumentValueData* v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("AirSpeed"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Air Speed"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Gps"), QStringLiteral("Lat"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Latitude"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("Pitch"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Pitch"));
    }

    // --- Column 2 (index 1) ---
    {
        QmlObjectListModel* col = columnModel(1);
        int rowIndex = 0;

        InstrumentValueData* v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("GroundSpeed"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Ground Speed"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Gps"), QStringLiteral("Lon"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Longitude"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("Roll"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Roll"));
    }

    // --- Column 3 (index 2) ---
    {
        QmlObjectListModel* col = columnModel(2);
        int rowIndex = 0;

        InstrumentValueData* v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("AltitudeRelative"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(v->fact() ? v->fact()->shortDescription() : QStringLiteral("Alt (Rel)"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("ClimbRate"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Climb Rate"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("PitchRate"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Pitch Rate"));
    }

    // --- Column 4 (index 3) ---
    {
        QmlObjectListModel* col = columnModel(3);
        int rowIndex = 0;

        InstrumentValueData* v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("ThrottlePct"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Thr"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("FlightTime"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Flight Time"));

        v = col->value<InstrumentValueData*>(rowIndex++);
        v->setFact(QStringLiteral("Vehicle"), QStringLiteral("RollRate"));
        v->setIcon(QStringLiteral(""));
        v->setRangeType(InstrumentValueData::NoRangeInfo);
        v->setShowUnits(true);
        v->setText(QStringLiteral("Roll Rate"));
    }
}

QQmlApplicationEngine *QGCCorePlugin::createQmlApplicationEngine(QObject *parent)
{
    QQmlApplicationEngine *const qmlEngine = new QQmlApplicationEngine(parent);
    qmlEngine->addImportPath(QStringLiteral("qrc:/qml"));
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("joystickManager"), JoystickManager::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("debugMessageModel"), QGCLogging::instance());
    return qmlEngine;
}

void QGCCorePlugin::createRootWindow(QQmlApplicationEngine *qmlEngine)
{
    qmlEngine->load(QUrl(QStringLiteral("qrc:/qml/QGroundControl/MainWindow.qml")));
}

VideoReceiver *QGCCorePlugin::createVideoReceiver(QObject *parent)
{
#ifdef QGC_GST_STREAMING
    return GStreamer::createVideoReceiver(parent);
#elif defined(QGC_QT_STREAMING)
    return QtMultimediaReceiver::createVideoReceiver(parent);
#else
    return nullptr;
#endif
}

void *QGCCorePlugin::createVideoSink(QQuickItem *widget, QObject *parent)
{
#ifdef QGC_GST_STREAMING
    return GStreamer::createVideoSink(widget, parent);
#elif defined(QGC_QT_STREAMING)
    return QtMultimediaReceiver::createVideoSink(widget, parent);
#else
    Q_UNUSED(widget); Q_UNUSED(parent);
    return nullptr;
#endif
}
void QGCCorePlugin::releaseVideoSink(void *sink)
{
#ifdef QGC_GST_STREAMING
    GStreamer::releaseVideoSink(sink);
#elif defined(QGC_QT_STREAMING)
    QtMultimediaReceiver::releaseVideoSink(sink);
#else
    Q_UNUSED(sink);
#endif
}

const QVariantList &QGCCorePlugin::toolBarIndicators()
{
    static const QVariantList toolBarIndicatorList = QVariantList(
        {
            QVariant::fromValue(QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/Toolbar/RTKGPSIndicator.qml"))),
        }
    );

    return toolBarIndicatorList;
}

QVariantList QGCCorePlugin::firstRunPromptsToShow()
{
    QList<int> rgIdsToShow;

    rgIdsToShow.append(firstRunPromptStdIds());
    rgIdsToShow.append(firstRunPromptCustomIds());

    const QList<int> rgAlreadyShownIds = AppSettings::firstRunPromptsIdsVariantToList(SettingsManager::instance()->appSettings()->firstRunPromptIdsShown()->rawValue());
    for (int idToRemove: rgAlreadyShownIds) {
        (void) rgIdsToShow.removeOne(idToRemove);
    }

    QVariantList rgVarIdsToShow;
    for (int id: rgIdsToShow) {
        rgVarIdsToShow.append(id);
    }

    return rgVarIdsToShow;
}

QString QGCCorePlugin::firstRunPromptResource(int id) const
{
    switch (id) {
    case kUnitsFirstRunPromptId:
        return QStringLiteral("/qml/QGroundControl/FirstRunPromptDialogs/UnitsFirstRunPrompt.qml");
    case kOfflineVehicleFirstRunPromptId:
        return QStringLiteral("/qml/QGroundControl/FirstRunPromptDialogs/OfflineVehicleFirstRunPrompt.qml");
    case kADDEditionFirstRunPromptId:
        return QStringLiteral("/qml/QGroundControl/FirstRunPromptDialogs/ADDEditionFirstRunPrompt.qml");
    default:
        return QString();
    }
}

void QGCCorePlugin::_setShowTouchAreas(bool show)
{
    if (show != _showTouchAreas) {
        _showTouchAreas = show;
        emit showTouchAreasChanged(show);
    }
}

void QGCCorePlugin::_setShowAdvancedUI(bool show)
{
    if (show != _showAdvancedUI) {
        _showAdvancedUI = show;
        emit showAdvancedUIChanged(show);
    }
}
