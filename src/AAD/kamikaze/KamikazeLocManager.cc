#include "QGCApplication.h"
#include <QApplicationStatic>
#include <QDebug>
#include "KamikazeLocManager.h"
#include <mavlink.h>
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "Fact.h"

#include "ServerManager.h"

Q_APPLICATION_STATIC(KamikazeLocManager, _kamikazeLocManager)

KamikazeLocManager* KamikazeLocManager::instance()
{
    return _kamikazeLocManager();
}
// also set params if activeVehicle
void KamikazeLocManager::setCoordinate(QGeoCoordinate coord)
{
    if (!coord.isValid()) {
        ServerManager::instance()->reportError(
            QStringLiteral("Invalid coordinates"),
            QStringLiteral("coord: %1,%2")
                .arg(QString::number(coord.latitude()))
                .arg(QString::number(coord.longitude()))
        );
        return;
    }

    // inside Turkey check (warning only)
    const double lat = coord.latitude();
    const double lon = coord.longitude();

    const bool inTurkey =
        lat >= 36.0 && lat <= 42.1 &&
        lon >= 26.0 && lon <= 45.0;

    if (!inTurkey) {
        ServerManager::instance()->reportError(
            QStringLiteral("warning"),
            QStringLiteral("coords not in Turkey (%1,%2)")
                .arg(QString::number(lat))
                .arg(QString::number(lon))
        );
    }

    _coordinate = coord;
    emit coordinateChanged();

    // Get active vehicle
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();
    if (vehicle) {
        qDebug() << "Active vehicle ID:" << vehicle->id();

        Fact* latFact = vehicle->parameterManager()->getParameter(
        vehicle->defaultComponentId(), "KAMIKAZE_LAT");
        Fact* lonFact = vehicle->parameterManager()->getParameter(
        vehicle->defaultComponentId(), "KAMIKAZE_LON");

        latFact->setRawValue(coord.latitude());
        lonFact->setRawValue(coord.longitude());

        qDebug() << "Kamikaze target set to" << coord.latitude() << coord.longitude();
    }else{
        ServerManager::instance()->reportError(
            QStringLiteral("Kamikaze Params are not set"),
            QStringLiteral("no activeVehicle!")
        );
    }
}

void KamikazeLocManager::clearCoordinate()
{
    _coordinate = QGeoCoordinate(); // default -> invalid
    emit coordinateChanged();
    qDebug() << "Kamikaze target cleared";

    // Get active vehicle
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();
    if(!vehicle){return;}

    Fact* latFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LON");

    latFact->setRawValue(0);
    lonFact->setRawValue(0);
}
