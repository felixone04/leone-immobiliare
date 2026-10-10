/// Mappe OpenStreetMap. Le "tessere" della mappa sono un contenuto esterno: si caricano solo
/// dopo il consenso del visitatore e se c'è la connessione. Senza, restano visibili i segnaposti
/// su uno sfondo neutro (mappa semplificata, utilizzabile offline).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../state/app_state.dart';
import '../kit.dart';

class MapPin {
  final LatLng pos;
  final String label;
  final String? icon;
  final String kind; // normal | muted | office | dot
  final Json? item; // annuncio collegato (popup)
  final String? popupTitle, popupText;
  const MapPin(this.pos, this.label, {this.icon, this.kind = 'normal', this.item, this.popupTitle, this.popupText});
}

class VMap extends StatefulWidget {
  final List<MapPin> pins;
  final LatLng? center;
  final double zoom;
  final double height;
  final ({LatLng pos, double radius})? circle;
  final bool fit;
  final void Function(LatLng)? onTap;
  final String? note;
  const VMap({super.key, this.pins = const [], this.center, this.zoom = 6, this.height = 460, this.circle, this.fit = true, this.onTap, this.note});

  @override
  State<VMap> createState() => _VMapState();
}

class _VMapState extends State<VMap> {
  final _ctrl = MapController();
  MapPin? _open;
  var _wheel = false;

  @override
  void didUpdateWidget(VMap old) {
    super.didUpdateWidget(old);
    if (widget.fit && _sig(old.pins) != _sig(widget.pins) && widget.pins.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.fitCamera(CameraFit.coordinates(coordinates: [for (final p in widget.pins) p.pos], padding: const EdgeInsets.all(40), maxZoom: 14));
      });
    }
  }

  static String _sig(List<MapPin> p) => p.map((x) => '${x.pos.latitude},${x.pos.longitude}').join('|');

  /// Inquadratura iniziale già adattata ai segnaposti. Con initialCameraFit la mappa partiva
  /// dallo zoom di base e le tessere dello zoom finale restavano invisibili finché non la si spostava.
  ({LatLng center, double zoom}) _inquadratura(LatLng center, double width, bool fit) {
    if (!fit || !width.isFinite || width <= 0) return (center: center, zoom: widget.zoom);
    final cam = CameraFit.coordinates(coordinates: [for (final p in widget.pins) p.pos], padding: const EdgeInsets.all(50), maxZoom: 14)
        .fit(MapCamera(crs: const Epsg3857(), center: center, zoom: widget.zoom, rotation: 0, nonRotatedSize: Size(width, widget.height), maxZoom: 19));
    return cam.zoom.isFinite ? (center: cam.center, zoom: cam.zoom) : (center: center, zoom: widget.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final consenso = s.repo.consenso == 'tutti';
    final pins = widget.pins;
    final center = widget.center ?? (pins.isNotEmpty ? pins.first.pos : const LatLng(42.5, 12.5));
    final useFit = widget.fit && pins.length > 1;

    if (!consenso) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(color: t.primarySoft, borderRadius: t.r, border: Border.all(color: t.line)),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          VIcon('map', size: 36, color: t.muted),
          const SizedBox(height: 6),
          Text('La mappa è fornita da OpenStreetMap, un servizio esterno.', textAlign: TextAlign.center, style: t.text(color: t.muted)),
          const SizedBox(height: 10),
          VButton('Mostra la mappa', kind: BtnKind.outline, size: BtnSize.sm, onAsync: () => s.repo.setConsenso('tutti')),
        ]),
      );
    }

    final markers = <Marker>[
      for (final p in pins)
        Marker(
          point: p.pos,
          width: p.kind == 'dot' ? 22 : 240,
          height: p.kind == 'dot' ? 22 : 44,
          alignment: p.kind == 'dot' ? Alignment.center : Alignment.topCenter,
          child: _PinWidget(pin: p, onTap: () => setState(() => _open = _open == p ? null : p)),
        ),
      if (_open != null && (_open!.item != null || _open!.popupTitle != null))
        Marker(
          point: _open!.pos,
          width: 260,
          height: _open!.item != null ? 260 : 110,
          alignment: const Alignment(0, -1.35),
          child: _Popup(pin: _open!, onClose: () => setState(() => _open = null)),
        ),
    ];

    return Container(
      height: widget.height,
      decoration: BoxDecoration(borderRadius: t.r, border: Border.all(color: t.line), color: t.primarySoft),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        MouseRegion(
          onExit: (_) => setState(() => _wheel = false),
          child: LayoutBuilder(builder: (context, box) {
            final start = _inquadratura(center, box.maxWidth, useFit);
            return FlutterMap(
              mapController: _ctrl,
              options: MapOptions(
                initialCenter: start.center,
                initialZoom: start.zoom,
                backgroundColor: t.primarySoft,
                maxZoom: 19,
                interactionOptions: InteractionOptions(
                  flags: _wheel ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.scrollWheelZoom,
                ),
                onTap: (_, ll) {
                  setState(() {
                    _wheel = true;
                    _open = null;
                  });
                  widget.onTap?.call(ll);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'it.vetrina.app',
                  maxZoom: 19,
                ),
                if (widget.circle != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: widget.circle!.pos,
                      radius: widget.circle!.radius,
                      useRadiusInMeter: true,
                      color: t.primary.withValues(alpha: .15),
                      borderColor: t.primary,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                MarkerLayer(markers: markers),
                const SimpleAttributionWidget(source: Text('OpenStreetMap')),
              ],
            );
          }),
        ),
        if (widget.note != null && widget.note!.isNotEmpty)
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: t.shadowSm),
              child: Text(widget.note!, style: t.text(size: 12.8)),
            ),
          ),
      ]),
    );
  }
}

class _PinWidget extends StatefulWidget {
  final MapPin pin;
  final VoidCallback onTap;
  const _PinWidget({required this.pin, required this.onTap});
  @override
  State<_PinWidget> createState() => _PinWidgetState();
}

class _PinWidgetState extends State<_PinWidget> {
  var _h = false;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = widget.pin;
    if (p.kind == 'dot') {
      return Container(decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))]));
    }
    final bg = switch (p.kind) { 'muted' => const Color(0xFF7B818A), 'office' => t.accent, _ => t.primary };
    final fg = p.kind == 'office' ? t.onAccent : (p.kind == 'muted' ? Colors.white : t.onPrimary);
    return Align(
      alignment: Alignment.bottomCenter,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _h ? 1.08 : 1,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 150),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (p.icon != null) ...[VIcon(p.icon!, size: 14, color: fg), const SizedBox(width: 5)],
                  Text(p.label, style: t.text(size: 12.5, weight: FontWeight.w700, color: fg, height: 1)),
                ]),
              ),
              Transform.translate(offset: const Offset(0, -5), child: Transform.rotate(angle: .785, child: Container(width: 10, height: 10, color: bg))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Popup extends StatelessWidget {
  final MapPin pin;
  final VoidCallback onClose;
  const _Popup({required this.pin, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final it = pin.item;
    Widget body;
    if (it != null) {
      final foto = s.cat.foto(it).firstOrNull;
      body = Hover(
        onTap: () => context.go('/scheda/${it['id']}'),
        builder: (_, h) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (foto != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 120, width: double.infinity, child: VImage(foto))),
          const SizedBox(height: 8),
          Text(s.cat.prezzo(it), style: t.text(size: 16.8, weight: FontWeight.w700, color: t.primary, height: 1.3)),
          Text(str(it['titolo']), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(weight: FontWeight.w600, height: 1.35)),
          Text(s.cat.luogo(it), style: t.text(size: 13, color: t.muted)),
        ]),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(pin.popupTitle ?? '', style: t.text(weight: FontWeight.w700)),
        if (pin.popupText != null) Text(pin.popupText!, style: t.text(size: 14)),
      ]);
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 3))]),
        child: Stack(children: [
          body,
          Positioned(right: -6, top: -6, child: IconBtn('x', size: 26, onPressed: onClose)),
        ]),
      ),
    );
  }
}

/// Segnaposti di tutti gli annunci geolocalizzati (+ eventuale sede).
List<MapPin> catalogPins(AppState s, List<Json> items) {
  final out = <MapPin>[];
  final sch = s.repo.schema;
  for (final i in items) {
    final g = s.cat.geo(i);
    if (g == null) continue;
    final p = numOrNull(i[sch.card.prezzo]);
    out.add(MapPin(LatLng(g.lat, g.lng), p == null ? sch.singolare : shortPrice(p), kind: s.cat.nastro(i).isNotEmpty ? 'muted' : 'normal', item: i));
  }
  return out;
}

MapPin? sedePin(AppState s) {
  final g = jsonOf(s.settings['sedeGeo']);
  final lat = numOrNull(g['lat']), lng = numOrNull(g['lng']);
  if (lat == null || lng == null) return null;
  return MapPin(LatLng(lat.toDouble(), lng.toDouble()), str(s.settings['nome']), icon: 'building', kind: 'office', popupTitle: str(s.settings['nome']), popupText: str(s.settings['indirizzo']));
}
