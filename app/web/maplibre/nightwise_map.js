/*
 * NightWise web map bridge.
 *
 * A thin adapter around MapLibre GL JS used by the Flutter web build. The map
 * uses real OpenStreetMap raster tiles, desaturated to the NightWise "quiet
 * map" palette, and draws the backend's real route geometry as GeoJSON layers.
 * No route or safety data is invented here.
 */
(function () {
  'use strict';

  if (window.NightWiseMap) return;

  const maps = Object.create(null);
  const pendingInits = Object.create(null);
  const pendingStates = Object.create(null);

  const palette = {
    canvas: '#e9e9e3',
    ink: '#121410',
    accent: '#c8f25b',
    muted: '#8b8f83',
  };

  const style = {
    version: 8,
    name: 'NightWise Quiet Map',
    sources: {
      osm: {
        type: 'raster',
        tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
        tileSize: 256,
        attribution:
          '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap</a> contributors',
        maxzoom: 19,
      },
    },
    layers: [
      {
        id: 'background',
        type: 'background',
        paint: { 'background-color': palette.canvas },
      },
      {
        id: 'osm',
        type: 'raster',
        source: 'osm',
        paint: {
          'raster-saturation': -1,
          'raster-contrast': -0.06,
          'raster-brightness-min': 0.22,
          'raster-brightness-max': 0.86,
          'raster-opacity': 0.94,
        },
      },
      {
        id: 'warmth',
        type: 'background',
        paint: { 'background-color': 'rgba(236,236,230,0.16)' },
      },
    ],
  };

  function markerElement(kind) {
    const el = document.createElement('div');
    el.className = 'nw-marker nw-marker-' + kind;
    const inner = document.createElement('span');
    el.appendChild(inner);
    return el;
  }

  function init(id, optionsJson) {
    const options = optionsJson ? JSON.parse(optionsJson) : {};
    pendingInits[id] = options;
    tryInit(id);
  }

  // Flutter attaches the platform-view element after the first frame, which can
  // be later than the Dart-side init call. Wait for the container instead of
  // silently giving up.
  function tryInit(id) {
    const options = pendingInits[id];
    if (!options) return;
    const container = document.getElementById(id);
    if (!container) {
      window.setTimeout(function () {
        tryInit(id);
      }, 40);
      return;
    }
    delete pendingInits[id];
    createMap(id, container, options);
  }

  function createMap(id, container, options) {
    if (maps[id]) {
      maps[id].map.remove();
      delete maps[id];
    }
    const maplibregl = window.maplibregl;
    if (!maplibregl) {
      container.innerHTML =
        '<div class="nw-map-error">Map library failed to load. Route data is still available in the list.</div>';
      return;
    }

    const map = new maplibregl.Map({
      container: container,
      style: style,
      center: [options.lng ?? 77.604, options.lat ?? 12.9756],
      zoom: options.zoom ?? 13.6,
      minZoom: 10.5,
      maxZoom: 18.5,
      attributionControl: false,
      dragRotate: false,
      pitchWithRotate: false,
      pitch: 0,
      bearing: 0,
      fadeDuration: 120,
      maxBounds: [
        [77.20, 12.62],
        [78.0, 13.32],
      ],
    });

    map.addControl(
      new maplibregl.AttributionControl({ compact: true, customAttribution: 'NightWise' }),
      'bottom-right'
    );

    map.on('load', function () {
      map.addSource('nw-routes-base', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });
      map.addSource('nw-routes-selected', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });

      map.addLayer({
        id: 'nw-route-casing',
        type: 'line',
        source: 'nw-routes-base',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': '#ffffff',
          'line-width': 9,
          'line-opacity': 0.85,
        },
      });
      map.addLayer({
        id: 'nw-route-line',
        type: 'line',
        source: 'nw-routes-base',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': palette.muted,
          'line-width': 4.5,
          'line-opacity': 0.8,
        },
      });
      map.addLayer({
        id: 'nw-route-casing-selected',
        type: 'line',
        source: 'nw-routes-selected',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': '#ffffff',
          'line-width': 12,
          'line-opacity': 0.95,
        },
      });
      map.addLayer({
        id: 'nw-route-line-selected',
        type: 'line',
        source: 'nw-routes-selected',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': palette.accent,
          'line-width': 7,
          'line-opacity': 1,
        },
      });

      const record = maps[id];
      if (record) record.loaded = true;
      if (record && record.pending) {
        const pending = record.pending;
        record.pending = null;
        update(id, pending);
      }
    });

    map.on('click', function (event) {
      if (typeof window.nightwiseOnMapTap === 'function') {
        window.nightwiseOnMapTap(event.lngLat.lng, event.lngLat.lat);
      }
    });

    const resize = new ResizeObserver(function () {
      map.resize();
    });
    resize.observe(container);

    maps[id] = {
      map: map,
      resize: resize,
      markers: {},
      container: container,
      pending: pendingStates[id] || options.state || null,
      loaded: false,
    };
    delete pendingStates[id];
  }

  function ensureMarkers(record, state) {
    const map = record.map;
    const maplibregl = window.maplibregl;
    const markers = record.markers;

    function setMarker(key, lngLat, kind) {
      if (!lngLat) {
        if (markers[key]) {
          markers[key].remove();
          delete markers[key];
        }
        return;
      }
      if (markers[key]) {
        markers[key].setLngLat([lngLat.lng, lngLat.lat]);
        return;
      }
      const marker = new maplibregl.Marker({
        element: markerElement(kind),
        anchor: kind === 'destination' ? 'bottom' : 'center',
      })
        .setLngLat([lngLat.lng, lngLat.lat])
        .addTo(map);
      markers[key] = marker;
    }

    setMarker('origin', state.origin, 'origin');
    setMarker('destination', state.destination, 'destination');
    setMarker('current', state.current, 'current');
  }

  function update(id, stateJson) {
    const state =
      typeof stateJson === 'string'
        ? JSON.parse(stateJson)
        : stateJson || {};
    const record = maps[id];
    if (!record) {
      const previous = pendingStates[id];
      if (previous && previous.fit) state.fit = true;
      pendingStates[id] = state;
      return;
    }
    if (!record.loaded) {
      if (record.pending && record.pending.fit) state.fit = true;
      record.pending = state;
      return;
    }
    const map = record.map;
    const selectedId = state.selectedRouteId;
    const routes = Array.isArray(state.routes) ? state.routes : [];
    const baseFeatures = [];
    const selectedFeatures = [];
    const bounds = new window.maplibregl.LngLatBounds();

    routes.forEach(function (route) {
      if (!route || !Array.isArray(route.coordinates) || route.coordinates.length < 2) return;
      const feature = {
        type: 'Feature',
        properties: { id: route.id, label: route.label || '' },
        geometry: { type: 'LineString', coordinates: route.coordinates },
      };
      if (selectedId && route.id === selectedId) {
        selectedFeatures.push(feature);
      } else {
        baseFeatures.push(feature);
      }
      route.coordinates.forEach(function (coord) {
        bounds.extend(coord);
      });
    });

    const base = map.getSource('nw-routes-base');
    const selected = map.getSource('nw-routes-selected');
    if (base) base.setData({ type: 'FeatureCollection', features: baseFeatures });
    if (selected) selected.setData({ type: 'FeatureCollection', features: selectedFeatures });

    ensureMarkers(record, state);

    if (state.follow && state.current) {
      map.easeTo({
        center: [state.current.lng, state.current.lat],
        zoom: Math.max(map.getZoom(), 16),
        duration: 500,
      });
      return;
    }

    if (state.fit && !bounds.isEmpty()) {
      map.fitBounds(bounds, {
        padding: state.fitPadding || { top: 100, right: 100, bottom: 230, left: 100 },
        duration: 650,
        maxZoom: 16.2,
      });
      return;
    }

    if (state.center && routes.length === 0) {
      const current = map.getCenter();
      const moved = Math.abs(current.lat - state.center.lat) > 0.00005 ||
        Math.abs(current.lng - state.center.lng) > 0.00005;
      if (moved || (state.zoom && Math.abs(map.getZoom() - state.zoom) > 0.05)) {
        map.easeTo({
          center: [state.center.lng, state.center.lat],
          zoom: state.zoom || map.getZoom(),
          duration: 450,
        });
      }
    }
  }

  function zoomBy(id, delta) {
    const record = maps[id];
    if (!record) return;
    record.map.easeTo({ zoom: record.map.getZoom() + delta, duration: 240 });
  }

  function recenter(id, lng, lat) {
    const record = maps[id];
    if (!record) return;
    record.map.easeTo({ center: [lng, lat], zoom: 15.2, duration: 500 });
  }

  function destroy(id) {
    delete pendingInits[id];
    delete pendingStates[id];
    const record = maps[id];
    if (!record) return;
    try {
      record.resize.disconnect();
      record.map.remove();
    } catch (error) {
      // The container may already be gone during a hot restart.
      console.warn('NightWise map cleanup failed', error);
    }
    delete maps[id];
  }

  window.NightWiseMap = {
    init: init,
    update: update,
    zoomBy: zoomBy,
    recenter: recenter,
    destroy: destroy,
    debug: function (id) {
      const record = maps[id];
      if (!record) return { exists: false, pending: pendingStates[id] || null };
      const base = record.map.getSource('nw-routes-base');
      const selected = record.map.getSource('nw-routes-selected');
      return {
        exists: true,
        loaded: record.loaded,
        pending: record.pending,
        markers: Object.keys(record.markers),
        base: base ? base._data : null,
        selected: selected ? selected._data : null,
        center: record.map.getCenter(),
        zoom: record.map.getZoom(),
      };
    },
  };
})();