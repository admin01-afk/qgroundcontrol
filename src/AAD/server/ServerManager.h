#pragma once

#include <QObject>
#include <QVariantMap>
#include <QJsonObject>
#include <QJsonArray>
#include <QGeoCoordinate>
#include <QProcess>
#include <QTimer>
#include <QStringList>

#include "TelemPlaneDataModel.h"

class QNetworkAccessManager;
class QNetworkReply;

class ServerManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool serversimRunning READ serversimRunning NOTIFY serversimRunningChanged)
    Q_PROPERTY(bool telemRunning READ telemRunning NOTIFY telemRunningChanged)
    Q_PROPERTY(QStringList logs READ logs NOTIFY logsChanged)
    Q_PROPERTY(TelemPlaneDataModel* telemPlaneDataModel READ telemPlaneDataModel CONSTANT)

public:
    TelemPlaneDataModel* telemPlaneDataModel() { return &_telemPlaneDataModel;}
    static ServerManager* instance();
    explicit ServerManager(QObject* parent = nullptr);
    Q_DISABLE_COPY(ServerManager)

    // ---- State ----
    bool serversimRunning() const;
    bool telemRunning() const;
    QStringList logs() const { return _logs; }

    // ---- QML API ----
    Q_INVOKABLE void setBaseUrl(const QString& url) { _baseUrl = url; }
    Q_INVOKABLE QString baseUrl() const { return _baseUrl; }

    Q_INVOKABLE void login(const QString& username, const QString& password);
    Q_INVOKABLE void getQRCoordinates();
    Q_INVOKABLE void checkConnection();

    Q_INVOKABLE void startServerSim();
    Q_INVOKABLE void stopServerSim();

    Q_INVOKABLE void toggleTelem();

    Q_INVOKABLE void clearLogs();

signals:
    void serversimRunningChanged();
    void telemRunningChanged();
    void logsChanged();

    void connectionResult(bool reachable);
    void errorOccurred(const QString& error);

    void loginSucceeded(int teamNumber);
    void loginFailed(const QString& reason);

    void qrCoordinatesReceived(const QGeoCoordinate& coord);

private:
    // ---- Helpers ----
    void requestJson(
        QNetworkAccessManager::Operation op,
        const QString& path,
        const QJsonObject* body,
        std::function<void(const QJsonObject&)> onSuccess
    );

    QJsonObject qvariantmapToJson(const QVariantMap& m) const;
    void appendLog(const QString& line);
    void _telemLoop();

    TelemPlaneDataModel _telemPlaneDataModel;

private:
    QNetworkAccessManager* _nam{nullptr};
    QString                _baseUrl{"http://127.0.0.1:5000"};

    QProcess* _serversimProcess{nullptr};
    QTimer*   _telemTimer{nullptr};

    QStringList _logs;
};
