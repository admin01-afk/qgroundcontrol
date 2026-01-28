#pragma once

#include <QAbstractListModel>
#include <QGeoCoordinate>
#include <QHash>

struct AircraftData {
    int teamId;
    QGeoCoordinate coord;
};

class TelemPlaneDataModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum roles {
        TeamIdRole = Qt::UserRole + 1,
        CoordinateRole
    };

    explicit TelemPlaneDataModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex&) const override;
    QVariant data(const QModelIndex&, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void updateAircraft(int teamId, const QGeoCoordinate& coord);

private:
    QList<AircraftData> _aircraft;
};
