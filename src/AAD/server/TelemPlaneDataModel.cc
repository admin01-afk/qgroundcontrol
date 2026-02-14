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
        case HeadingRole: return a.heading;
        case AltRole: return a.alt;
        case SpeedRole: return a.speed;
    }
    return {};
}

QHash<int, QByteArray> TelemPlaneDataModel::roleNames() const {
    return {
        { TeamIdRole, "teamId" },
        { CoordinateRole, "coordinate" },
        { HeadingRole, "heading" },
        { AltRole, "alt"},
        { SpeedRole, "speed"}
    };
}

void TelemPlaneDataModel::updateAircraft(int teamId, const QGeoCoordinate& coord, double heading, double alt, double speed)
{
    for (int i = 0; i < _aircraft.size(); ++i) {
        if (_aircraft[i].teamId == teamId) {
            _aircraft[i].coord = coord;
            _aircraft[i].heading = heading;
            _aircraft[i].alt = alt;
            _aircraft[i].speed = speed;
            emit dataChanged(index(i), index(i), { CoordinateRole, HeadingRole, AltRole, SpeedRole });
            return;
        }
    }

    // new aircraft
    beginInsertRows({}, _aircraft.size(), _aircraft.size());
    _aircraft.append({ teamId, coord, heading, alt, speed });
    endInsertRows();
}

void TelemPlaneDataModel::removeAircraftNotIn(const QSet<int>& activeIds)
{
    // Build new list containing only active aircraft
    QList<AircraftData> newList;
    newList.reserve(_aircraft.size());

    for (const AircraftData& a : _aircraft) {
        if (activeIds.contains(a.teamId)) {
            newList.append(a);
        }
    }

    // If nothing changed, do nothing
    if (newList.size() == _aircraft.size()) {
        bool same = true;
        for (int i = 0; i < newList.size(); ++i) {
            if (newList[i].teamId != _aircraft[i].teamId) { same = false; break; }
        }
        if (same) return;
    }

    // Replace model using model reset (safe, simple)
    beginResetModel();
    _aircraft = std::move(newList);
    endResetModel();
}
