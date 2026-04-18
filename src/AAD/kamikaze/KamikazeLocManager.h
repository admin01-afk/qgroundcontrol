#pragma once

#include <QtCore/QObject>
#include <QGeoCoordinate>

class Vehicle;

class KamikazeLocManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QGeoCoordinate coordinate READ coordinate WRITE setCoordinate NOTIFY coordinateChanged)
    Q_PROPERTY(bool isQRparamSet READ isQRparamSet NOTIFY isQRparamSetChanged)

public:
    static KamikazeLocManager* instance();

    Q_INVOKABLE void setCoordinate(QGeoCoordinate coord);
    Q_INVOKABLE void sendParameters(QGeoCoordinate coord);
    Q_INVOKABLE void clearCoordinate();

    QGeoCoordinate coordinate() const { return _coordinate; }

    bool isQRparamSet() const { return _isQRparamSet; }

signals:
    void coordinateChanged();
    void isQRparamSetChanged();

private:
    QGeoCoordinate _coordinate;
    bool _isQRparamSet = false;

    void updateIsQRparamSet();
    void _setupVehicle(Vehicle* vehicle);
    void _syncFromVehicle(Vehicle* vehicle);
    void _init();
};
