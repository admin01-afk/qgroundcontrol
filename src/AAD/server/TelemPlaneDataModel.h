#pragma once

#include <QAbstractListModel>
#include <QGeoCoordinate>
#include <QHash>

struct AircraftData {
    int teamId;
    QGeoCoordinate coord;
    double heading = 0.0;
    double alt = 0.0;
    double speed = 0.0;
};

class TelemPlaneDataModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum roles {
        TeamIdRole = Qt::UserRole + 1,
        CoordinateRole,
        HeadingRole,
        AltRole,
        SpeedRole
    };

    explicit TelemPlaneDataModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex&) const override;
    QVariant data(const QModelIndex&, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void updateAircraft(
        int teamId,
        const QGeoCoordinate& coord,
        double heading = 0.0,
        double alt = 0.0,
        double speed = 0.0
    );
    void removeAircraftNotIn(const QSet<int>& activeIds);

signals:
    void aircraftListChanged();

private:
    QList<AircraftData> _aircraft;
};
