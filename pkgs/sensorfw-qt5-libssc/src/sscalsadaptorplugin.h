/****************************************************************************
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#ifndef SSCALSADAPTORPLUGIN_H
#define SSCALSADAPTORPLUGIN_H

#include "plugin.h"

class SscAlsAdaptorPlugin : public Plugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.nokia.SensorService.Plugin/1.0")

private:
    void Register(class Loader &l);
};

#endif
