/****************************************************************************
**
** sensorfw-qt5-libssc — Qualcomm SSC accelerometer adaptor for Sailfish
** Copyright (C) 2026 PAD6-DEV
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#ifndef SSCACCELEROMETERADAPTOR_H
#define SSCACCELEROMETERADAPTOR_H

#include "deviceadaptor.h"
#include "deviceadaptorringbuffer.h"
#include "datatypes/orientationdata.h"

#include <QTimer>

typedef struct _SSCSensorAccelerometer SSCSensorAccelerometer;

/**
 * Sensorfw device adaptor that reads acceleration from libssc (Qualcomm SSC).
 * Registers as plugin type "accelerometeradaptor".
 */
class SscAccelerometerAdaptor : public DeviceAdaptor
{
    Q_OBJECT

public:
    static DeviceAdaptor *factoryMethod(const QString &id)
    {
        return new SscAccelerometerAdaptor(id);
    }

    explicit SscAccelerometerAdaptor(const QString &id);
    ~SscAccelerometerAdaptor() override;

    void init() override;
    bool startAdaptor() override;
    void stopAdaptor() override;
    bool startSensor() override;
    void stopSensor() override;

private slots:
    void pumpGlib();

private:
    friend void sscAccelMeasurementTrampoline(SSCSensorAccelerometer *sensor,
                                              float x, float y, float z,
                                              void *userData);
    void handleMeasurement(float x, float y, float z);

    DeviceAdaptorRingBuffer<AccelerationData> *buffer_;
    SSCSensorAccelerometer *sensor_;
    unsigned long measurementHandlerId_;
    QTimer *glibTimer_;
    bool sensorOpen_;
};

#endif
