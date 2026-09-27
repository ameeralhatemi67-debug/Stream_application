(() => {
  const m = (id, en, ar, venueEn, venueAr, lat, lng, city) => ({
    markerId: 'pin_' + id, streamerId: id, displayNameEn: en, displayNameAr: ar,
    venueNameEn: venueEn, venueNameAr: venueAr, latitude: lat, longitude: lng,
    cityId: city, categoryId: 'cs_tech', avatarUrl: '', isOrganization: false,
  });
  const list = [
    m('fx_khobar', 'Fixture Corniche Hall', 'قاعة الكورنيش التجريبية', 'Corniche test venue', 'مكان تجريبي', 26.2890, 50.2170, 'khobar'),
    m('fx_kfupm', 'Fixture KFUPM Lecture', 'محاضرة تجريبية', 'KFUPM test venue', 'مكان تجريبي', 26.3070, 50.1440, 'dhahran'),
    m('fx_dammam', 'Fixture Dammam Centre', 'مركز الدمام التجريبي', 'Dammam test venue', 'مكان تجريبي', 26.4280, 50.0950, 'dammam'),
    m('fx_twin_a', 'Fixture Twin A', 'توأم أ', 'Same point A', 'نفس النقطة أ', 26.3040, 50.1960, 'khobar'),
    m('fx_twin_b', 'Fixture Twin B', 'توأم ب', 'Same point B', 'نفس النقطة ب', 26.3040, 50.1960, 'khobar'),
    m('fx_riyadh', 'Fixture Riyadh Hall', 'قاعة الرياض', 'Riyadh test venue', 'مكان تجريبي', 24.7136, 46.6753, 'riyadh'),
    m('fx_null', 'Fixture Null Island', 'صفر', 'Invalid point', 'نقطة غير صالحة', 0, 0, 'other'),
  ];
  localStorage.setItem('flutter.spatial_map_marker_cache_v2', JSON.stringify(JSON.stringify(list)));
  localStorage.setItem('flutter.spatial_map_marker_cache_updated_at_v2', JSON.stringify('2026-09-26T15:00:00.000'));
  return 'seeded ' + list.length;
})()
