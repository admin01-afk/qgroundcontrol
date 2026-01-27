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
// also set params if activeVehicle
void KamikazeLocManager::setCoordinate(QGeoCoordinate coord)
{
    if (!coord.isValid()) {return;}

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
        qDebug() << "Kamikaze Params are not set, no connection! \t | " << coord.latitude() << coord.longitude();
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
