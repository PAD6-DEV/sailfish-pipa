/****************************************************************************
**
** sensorfw-qt5-libssc — Qualcomm SSC ALS adaptor for Sailfish
** Copyright (C) 2026 PAD6-DEV
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#ifndef SSCALSADAPTOR_H
#define SSCALSADAPTOR_H

#include "deviceadaptor.h"
#include "deviceadaptorringbuffer.h"
#include "datatypes/timedunsigned.h"

#include <QTimer>

typedef struct _SSCSensorLight SSCSensorLight;

/**
 * Sensorfw device adaptor that reads ambient light (lux) from libssc.
 * Registers as plugin type "alsadaptor".
 */
class SscAlsAdaptor : public DeviceAdaptor
{
    Q_OBJECT

public:
    static DeviceAdaptor *factoryMethod(const QString &id)
    {
        return new SscAlsAdaptor(id);
    }

    explicit SscAlsAdaptor(const QString &id);
    ~SscAlsAdaptor() override;

    void init() override;
    bool startAdaptor() override;
    void stopAdaptor() override;
    bool startSensor() override;
    void stopSensor() override;

private slots:
    void pumpGlib();

private:
    friend void sscAlsMeasurementTrampoline(SSCSensorLight *sensor,
                                            float intensity,
                                            void *userData);
    void handleMeasurement(float intensity);

    DeviceAdaptorRingBuffer<TimedUnsigned> *buffer_;
    SSCSensorLight *sensor_;
    unsigned long measurementHandlerId_;
    QTimer *glibTimer_;
    bool sensorOpen_;
};

#endif
