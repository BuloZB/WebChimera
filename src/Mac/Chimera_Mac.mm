#include "Chimera_Mac.h"

#include <QQmlContext>

#include <QuickLayer/QuickLayer.h>
#include <QuickLayer/FboQuickView.h>

////////////////////////////////////////////////////////////////////////////////
//Chimera_Mac class
////////////////////////////////////////////////////////////////////////////////
void Chimera_Mac::StaticInitialize()
{
    QmlChimera::StaticInitialize();
}

void Chimera_Mac::StaticDeinitialize()
{
}

Chimera_Mac::Chimera_Mac()
    : m_quickLayer( 0 )
{
}

Chimera_Mac::~Chimera_Mac()
{
    cleanup();
}

void Chimera_Mac::cleanup()
{
    if( m_quickLayer ) {
        [(QuickLayer*)m_quickLayer release];
        m_quickLayer = 0;
    }

    m_quickViewPtr.reset();
}

bool Chimera_Mac::onWindowAttached( FB::AttachedEvent*, FB::PluginWindowMacCA* w )
{
    vlc_open();

    typedef FB::PluginWindowMac PW;
    if( PW::DrawingModelCoreAnimation == w->getDrawingModel() ||
        PW::DrawingModelInvalidatingCoreAnimation == w->getDrawingModel() )
    {
        m_quickViewPtr.reset( new FboQuickView() );

        QuickLayer* layer = [[QuickLayer alloc] initWithFboQuickWindow: m_quickViewPtr.data()];
        m_quickLayer = layer;
        layer.asynchronous =
            ( PW::DrawingModelInvalidatingCoreAnimation == w->getDrawingModel() ) ?
                NO : YES;
        layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        layer.needsDisplayOnBoundsChange = YES;

        if( PW::DrawingModelInvalidatingCoreAnimation == w->getDrawingModel() )
            w->StartAutoInvalidate( 1. / 30. );
        [(CALayer*) w->getDrawingPrimitive() addSublayer: layer];
    } else {
        assert( false );
    }

    apply_player_options();
    setQml();

    return true;
}

bool Chimera_Mac::onWindowDetached( FB::DetachedEvent*, FB::PluginWindowMacCA* )
{
    cleanup();

    return true;
}

void Chimera_Mac::setQml()
{
    if( !m_quickViewPtr )
        return;

    if( m_quickViewPtr ) {
        QQmlContext* context = m_quickViewPtr->rootContext();
        context->setContextObject( this );
        context->setContextProperty( QStringLiteral( "plugin" ), this );
    }

    const std::string& qml = get_options().get_qml();
    if( qml.empty() ) {
        m_quickViewPtr->setSource( getQmlSource() );
    } else {
        QUrl qmlUrl = QStringLiteral( "qml" );
        m_quickViewPtr->setQml( QString::fromStdString( qml ), qmlUrl );
    }

    //FIXME! handle qml errors and fill m_qmlErrory
}

void Chimera_Mac::on_option_change( vlc_player_option_e o )
{
    QmlChimera::on_option_change( o );

    if( po_qml == o ) {
        setQml();
    }
}
