#include "ServerManager.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <QDebug>
#include <functional>
#include <QApplicationStatic>
#include <QDir>

Q_APPLICATION_STATIC(ServerManager, _serverManager)

ServerManager* ServerManager::instance()
{
    return _serverManager();
}

ServerManager::ServerManager(QObject* parent)
    : QObject(parent)
{
    _nam = new QNetworkAccessManager(this);

    // init telemTimer
    _telemTimer = new QTimer(this);
    _telemTimer->setInterval(1000); // 1 Hz
    connect(_telemTimer, &QTimer::timeout,this, &ServerManager::_telemLoop);

    connect(qApp, &QCoreApplication::aboutToQuit,this, &ServerManager::stopServerSim); // prevent stray servers sim processes
}

/* helpers */

void ServerManager::requestJson(
    QNetworkAccessManager::Operation op,
    const QString& path,
    const QJsonObject* body,
    std::function<void(const QJsonObject&)> onSuccess)
{
    QUrl url(_baseUrl + path);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply* reply = nullptr;

    if (op == QNetworkAccessManager::GetOperation) {
        reply = _nam->get(req);
    }
    else if (op == QNetworkAccessManager::PostOperation) {
        QByteArray payload = body
            ? QJsonDocument(*body).toJson(QJsonDocument::Compact)
            : QByteArray{};
        reply = _nam->post(req, payload);
    }
    else {
        emit errorOccurred("Unsupported HTTP operation");
        return;
    }

    connect(reply, &QNetworkReply::finished, this,
        [this, reply, onSuccess]()
        {
            const int httpStatus =
                reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            const QByteArray data = reply->readAll();

            // Network-level errors
            if (reply->error() != QNetworkReply::NoError) {
                emit errorOccurred(
                    QString("HTTP %1: %2\n%3")
                        .arg(httpStatus)
                        .arg(reply->errorString())
                        .arg(QString::fromUtf8(data))
                );
                reply->deleteLater();
                return;
            }

            // JSON parsing
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(data, &err);

            if (err.error != QJsonParseError::NoError || !doc.isObject()) {
                emit errorOccurred(
                    QString("Invalid JSON response (HTTP %1)").arg(httpStatus)
                );
                reply->deleteLater();
                return;
            }

            if (onSuccess)
                onSuccess(doc.object());

            reply->deleteLater();
        });
}

QJsonObject ServerManager::qvariantmapToJson(const QVariantMap& m) const
{
    QJsonObject obj;
    for (auto it = m.constBegin(); it != m.constEnd(); ++it) {
        const QVariant& v = it.value();
        switch (v.typeId()) {
        case QMetaType::Bool:
            obj.insert(it.key(), v.toBool());
            break;
        case QMetaType::Int:
        case QMetaType::LongLong:
            obj.insert(it.key(), QJsonValue::fromVariant(v.toLongLong()));
            break;
        case QMetaType::Double:
            obj.insert(it.key(), v.toDouble());
            break;
        default:
            obj.insert(it.key(), QJsonValue(v.toString()));
            break;
        }
    }
    return obj;
}

/* API methods */

void ServerManager::login(const QString& username, const QString& password)
{
    QJsonObject body{
        {"kadi", username},
        {"sifre", password}
    };

    requestJson(
        QNetworkAccessManager::PostOperation,
        "/api/giris",
        &body,
        [this](const QJsonObject& obj)
        {
            if (obj.contains("takim_numarasi"))
                emit loginSucceeded(obj["takim_numarasi"].toInt());
            else
                emit loginFailed(obj.value("error").toString("Login failed"));
        }
    );
}

void ServerManager::getQRCoordinates()
{
    requestJson(
        QNetworkAccessManager::GetOperation,
        "/api/qr_koordinati",
        nullptr,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("qrEnlem") || !obj.contains("qrBoylam")) {
                emit errorOccurred("Invalid QR coordinate payload");
                return;
            }

            emit qrCoordinatesReceived(QGeoCoordinate(
                obj["qrEnlem"].toDouble(),
                obj["qrBoylam"].toDouble()
            ));
        }
    );
}

void ServerManager::checkConnection()
{
    QNetworkRequest req{ QUrl(_baseUrl) };
    req.setAttribute(QNetworkRequest::RedirectionTargetAttribute, true);

    QNetworkReply* reply = _nam->head(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        // Network-level failure ONLY
        if (reply->error() == QNetworkReply::HostNotFoundError ||
            reply->error() == QNetworkReply::ConnectionRefusedError ||
            reply->error() == QNetworkReply::TimeoutError) {

            emit connectionResult(false);
        } else {
            // ANY HTTP response (200, 404, 500, etc.)
            emit connectionResult(true);
        }

        reply->deleteLater();
    });
}

void ServerManager::startServerSim()
{
    if (_serversimProcess) {qWarning() << "Server sim already running";return;}

    _serversimProcess = new QProcess(this);
    _serversimProcess->setProcessChannelMode(QProcess::MergedChannels);

    connect(_serversimProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        if (!_serversimProcess) return;

        const QByteArray data = _serversimProcess->readAllStandardOutput();
        const QString text = QString::fromUtf8(data);

        for (const QString& line : text.split('\n', Qt::SkipEmptyParts)) {
            emit serverLog(line);
        }
    });

    connect(_serversimProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus status) {
                qWarning() << "Server sim exited:" << code << status;
                QString msg = QStringLiteral("Server sim exited: %1 (%2)").arg(code).arg(status);
                emit serverError(msg);
                _serversimProcess->deleteLater();
                _serversimProcess = nullptr;
                emit serversimRunningChanged();   // ✅ state changed
            });

    const QString server_sim_script =
        QDir::homePath() + "/qgroundcontrol/src/AAD/server_sim/server.py";
    _serversimProcess->start("python3", { server_sim_script });
    if (!_serversimProcess->waitForStarted(1500)) {
        QString err = QString("Failed to start server sim: %1").arg(server_sim_script);
        emit serverError(err);
        _serversimProcess->deleteLater();
        _serversimProcess = nullptr;
        emit serversimRunningChanged();
        return;
    }
    emit serversimRunningChanged();   // ✅ state changed
}

void ServerManager::stopServerSim()
{
    if (!_serversimProcess) return;
    _serversimProcess->terminate();
}

bool ServerManager::serversimRunning() const{
    return _serversimProcess != nullptr &&
           _serversimProcess->state() != QProcess::NotRunning;
}

void ServerManager::_telemLoop()
{
    qDebug() << "[TELEM] tick";

    QJsonObject body{
        {"takim_numarasi", 3}
        //TODO
    };

    requestJson(
        QNetworkAccessManager::PostOperation,
        "/api/telemetri_gonder",
        &body,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("konum_bilgileri") || !obj["konum_bilgileri"].isArray()) {
                qWarning() << "No konum_bilgileri in response";
                return;
            }

            QJsonArray arr = obj["konum_bilgileri"].toArray();
            for (const QJsonValue& v : arr) {
                QJsonObject o = v.toObject();
                int id = o["takim_numarasi"].toInt();
                qDebug() << "takim_numarasi:" << id;
            }
        }
    );
}

bool ServerManager::telemRunning() const
{
    return _telemTimer && _telemTimer->isActive();
}

void ServerManager::toggleTelem()
{
    telemRunning() ? _telemTimer->stop() : _telemTimer->start();
    emit telemRunningChanged();
}
