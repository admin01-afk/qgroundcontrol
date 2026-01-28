#include "TelemPlaneDataModel.h"

TelemPlaneDataModel::TelemPlaneDataModel(QObject* parent)
    : QAbstractListModel(parent) {}

int TelemPlaneDataModel::rowCount(const QModelIndex&) const {
    return _aircraft.size();
}

QVariant TelemPlaneDataModel::data(const QModelIndex& idx, int role) const {
    if (!idx.isValid()) return {};

    const auto& a = _aircraft[idx.row()];
    switch (role) {
        case TeamIdRole: return a.teamId;
        case CoordinateRole: return QVariant::fromValue(a.coord);
    }
    return {};
}

QHash<int, QByteArray> TelemPlaneDataModel::roleNames() const {
    return {
        { TeamIdRole, "teamId" },
        { CoordinateRole, "coordinate" }
    };
}

void TelemPlaneDataModel::updateAircraft(int teamId, const QGeoCoordinate& coord)
{
    for (int i = 0; i < _aircraft.size(); ++i) {
        if (_aircraft[i].teamId == teamId) {
            _aircraft[i].coord = coord;
            emit dataChanged(index(i), index(i), { CoordinateRole });
            return;
        }
    }

    // new aircraft
    beginInsertRows({}, _aircraft.size(), _aircraft.size());
    _aircraft.append({ teamId, coord });
    endInsertRows();
}
