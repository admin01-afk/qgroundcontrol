#pragma once

#include <QtCore/QObject>
#include <QtCore/QVariantMap>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonArray>
#include <QGeoCoordinate>

class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

class ServerManager : public QObject
{
    Q_OBJECT

public:
    static ServerManager* instance();

    explicit ServerManager(QObject* parent = nullptr);
    Q_DISABLE_COPY(ServerManager)

    // QML / C++ API
    Q_INVOKABLE void setBaseUrl(const QString& url) { _baseUrl = url; }
    Q_INVOKABLE QString baseUrl() const { return _baseUrl; }

    Q_INVOKABLE void login(const QString& username, const QString& password);
    Q_INVOKABLE void getQRCoordinates();

signals:
    void errorOccurred(const QString& error);

    // login
    void loginSucceeded(int teamNumber);
    void loginFailed(const QString& reason);

    // qr coords
    void qrCoordinatesReceived(const QGeoCoordinate& coord);

private:
    QNetworkAccessManager* _nam{nullptr};
    QString                _baseUrl{"http://127.0.0.1:5000"};

    // helpers used by the implemented functions
    void processReplyJson(QNetworkReply* reply, std::function<void(const QJsonObject&)> onSuccess);
    QJsonObject qvariantmapToJson(const QVariantMap& m) const;
};
