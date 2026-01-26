#pragma once

#include <QtCore/QObject>
#include <QtCore/QVariantMap>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonArray>
#include <QGeoCoordinate>
#include <QProcess>

class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

class ServerManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool serversimRunning READ serversimRunning NOTIFY serversimRunningChanged)

public:
    static ServerManager* instance();

    explicit ServerManager(QObject* parent = nullptr);
    Q_DISABLE_COPY(ServerManager)
    bool serversimRunning() const;

    // QML / C++ API
    Q_INVOKABLE void setBaseUrl(const QString& url) { _baseUrl = url; }
    Q_INVOKABLE QString baseUrl() const { return _baseUrl; }

    Q_INVOKABLE void login(const QString& username, const QString& password);
    Q_INVOKABLE void getQRCoordinates();

    Q_INVOKABLE void checkConnection();
    Q_INVOKABLE void startServerSim();
    Q_INVOKABLE void stopServerSim();

signals:
    void serversimRunningChanged();
    void connectionResult(bool reachable);
    void errorOccurred(const QString& error);

    // login
    void loginSucceeded(int teamNumber);
    void loginFailed(const QString& reason);

    // qr coords
    void qrCoordinatesReceived(const QGeoCoordinate& coord);

    // server sim
    void serverLog(const QString& line);
    void serverError(const QString& line);

private:
    QNetworkAccessManager* _nam{nullptr};
    QString                _baseUrl{"http://127.0.0.1:5000"};

    // helpers used by the implemented functions
    void processReplyJson(QNetworkReply* reply, std::function<void(const QJsonObject&)> onSuccess);
    QJsonObject qvariantmapToJson(const QVariantMap& m) const;
    QProcess* _serversimProcess = nullptr;
};
