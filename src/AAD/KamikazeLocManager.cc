#include "QGCApplication.h"
#include <QApplicationStatic>
#include <QDebug>
#include "KamikazeLocManager.h"
#include <mavlink.h>
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "Fact.h"

Q_APPLICATION_STATIC(KamikazeLocManager, _kamikazeLocManager)

KamikazeLocManager* KamikazeLocManager::instance()
{
    return _kamikazeLocManager();
}

void KamikazeLocManager::setCoordinate(QGeoCoordinate coord)
{
    if (!coord.isValid()) {
        return;
    }

    _coordinate = coord;
    emit coordinateChanged();

    // Get active vehicle
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();
    if (vehicle) {qDebug() << "Active vehicle ID:" << vehicle->id();}

    Fact* latFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LON");

    // int32_t lat = static_cast<int32_t>(coord.latitude());
    // int32_t lon = static_cast<int32_t>(coord.longitude());

    latFact->setRawValue(coord.latitude());
    lonFact->setRawValue(coord.longitude());

    qDebug() << "Kamikaze target set to" << coord.latitude() << coord.longitude();
}

void KamikazeLocManager::clearCoordinate()
{
    _coordinate = QGeoCoordinate(); // default -> invalid
    emit coordinateChanged();

    // Get active vehicle
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();

    Fact* latFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = vehicle->parameterManager()->getParameter(
    vehicle->defaultComponentId(), "KAMIKAZE_LON");

    latFact->setRawValue(0);
    lonFact->setRawValue(0);
    qDebug() << "Kamikaze target cleared";
}
