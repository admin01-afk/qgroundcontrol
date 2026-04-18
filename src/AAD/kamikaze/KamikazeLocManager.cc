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
    _kamikazeLocManager()->_init();
    return _kamikazeLocManager();
}

void KamikazeLocManager::_init()
{
    MultiVehicleManager* manager = MultiVehicleManager::instance();

    // 🔹 handle already active vehicle
    if (manager->activeVehicle()) {
        _setupVehicle(manager->activeVehicle());
    }
    // 🔹 future connections
    connect(manager, &MultiVehicleManager::vehicleAdded,
            this, &KamikazeLocManager::_setupVehicle, Qt::UniqueConnection);
    // 🔹 vehicle switching
    connect(manager, &MultiVehicleManager::activeVehicleChanged,
            this, &KamikazeLocManager::_setupVehicle, Qt::UniqueConnection);
    
    // Timer check if vehicle qr params match _coordinate
    QTimer* timer = new QTimer(this);
    timer->setInterval(1000);
    connect(timer, &QTimer::timeout, this, [this]() {
        auto vehicle = MultiVehicleManager::instance()->activeVehicle();
        if (vehicle) _syncFromVehicle(vehicle);
    });
    timer->start();
}

void KamikazeLocManager::_syncFromVehicle(Vehicle* vehicle)
{
    if (!vehicle) return;

    auto pm = vehicle->parameterManager();
    Fact* latFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LON");
    if (!latFact || !lonFact) return;

    const double lat = latFact->rawValue().toDouble();
    const double lon = lonFact->rawValue().toDouble();

    const bool valid = (lat != 0.0 && lon != 0.0);

    // QR state
    if (_isQRparamSet != valid) {
        _isQRparamSet = valid;
        emit isQRparamSetChanged();
    }

    // coordinate sync
    QGeoCoordinate newCoord;
    if (valid) {
        newCoord = QGeoCoordinate(lat, lon);
    }

    if (_coordinate != newCoord && !_coordinate.isValid()) {
        _coordinate = newCoord;
        emit coordinateChanged();
    }
}

void KamikazeLocManager::_setupVehicle(Vehicle* vehicle)
{
    if (!vehicle) return;

    auto pm = vehicle->parameterManager();
    Fact* latFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LON");
    if (!latFact || !lonFact) return;

    connect(latFact, &Fact::rawValueChanged,
        this, [this, vehicle]() { _syncFromVehicle(vehicle); });

    connect(lonFact, &Fact::rawValueChanged,
        this, [this, vehicle]() { _syncFromVehicle(vehicle); });

    connect(pm, &ParameterManager::parametersReadyChanged,
            this, [this, vehicle](bool ready) {
                if (ready) {
                    _syncFromVehicle(vehicle);
                }
            });

    if (pm->parametersReady()) {
        _syncFromVehicle(vehicle);
    }
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

    MultiVehicleManager* manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();

    if (vehicle) {
        auto pm = vehicle->parameterManager();
        Fact* latFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LAT");
        Fact* lonFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LON");

        if (latFact && lonFact) {
            const double lat_param = latFact->rawValue().toDouble();
            const double lon_param = lonFact->rawValue().toDouble();

            const double eps = 1e-6;

            bool matches =
                qAbs(lat_param - coord.latitude()) < eps &&
                qAbs(lon_param - coord.longitude()) < eps;

            if (_isQRparamSet != matches) {
                _isQRparamSet = matches;
                emit isQRparamSetChanged();
            }
        }
    }

    _coordinate = coord;
    emit coordinateChanged();
}

void KamikazeLocManager::sendParameters(QGeoCoordinate coord){
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

    _syncFromVehicle(vehicle);
}

void KamikazeLocManager::clearCoordinate()
{
    MultiVehicleManager* manager = MultiVehicleManager::instance();
    Vehicle* vehicle = manager->activeVehicle();

    // UI state first
    if (_coordinate.isValid()) {
        _coordinate = QGeoCoordinate();
        emit coordinateChanged();
    }

    if (_isQRparamSet) {
        _isQRparamSet = false;
        emit isQRparamSetChanged();
    }

    if (!vehicle) return;

    auto pm = vehicle->parameterManager();
    Fact* latFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LAT");
    Fact* lonFact = pm->getParameter(vehicle->defaultComponentId(), "KAMIKAZE_LON");

    if (!latFact || !lonFact) return;

    latFact->setRawValue(0);
    lonFact->setRawValue(0);

    qDebug() << "Cleared QR params";
}
