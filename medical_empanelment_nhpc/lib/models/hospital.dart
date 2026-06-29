class Hospital {
  final String hosp_id;
  final String Hosp_name;
  final String Cont_person;
  final String Cont_no;
  final String hosp_add;
  final String valid_from;
  final String VALID_UPTO;
  final String LINK_ADD;
  final String LOC_CODE;
  final String SCHEME;
  final String Rem;
  final String ACC_Link_Add;
  final String RegValidUptoDt;
  final String Hosp_Offer;
  final String Hosp_name_H;
  final String hosp_add_H;
  final String Rem_h;
  final String latitude;
  final String longitude;

  Hospital({
    required this.hosp_id,
    required this.Hosp_name,
    required this.Cont_person,
    required this.Cont_no,
    required this.hosp_add,
    required this.valid_from,
    required this.VALID_UPTO,
    required this.LINK_ADD,
    required this.LOC_CODE,
    required this.SCHEME,
    required this.Rem,
    required this.ACC_Link_Add,
    required this.RegValidUptoDt,
    required this.Hosp_Offer,
    required this.Hosp_name_H,
    required this.hosp_add_H,
    required this.Rem_h,
    required this.latitude,
    required this.longitude,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      hosp_id: json['hosp_id'].toString(),
      Hosp_name: json['Hosp_name'] ?? '',
      Cont_person: json['Cont_person'] ?? '',
      Cont_no: json['Cont_no'] ?? '',
      hosp_add: json['hosp_add'] ?? '',
      valid_from: json['valid_from'] ?? '',
      VALID_UPTO: json['VALID_UPTO'] ?? '',
      LINK_ADD: json['LINK_ADD'] ?? '',
      LOC_CODE: json['LOC_CODE'] ?? '',
      SCHEME: json['SCHEME'] ?? '',
      Rem: json['Rem'] ?? '',
      ACC_Link_Add: json['ACC_Link_Add'] ?? '',
      RegValidUptoDt: json['RegValidUptoDt'] ?? '',
      Hosp_Offer: json['Hosp_Offer'] ?? '',
      Hosp_name_H: json['Hosp_name_H'] ?? '',
      hosp_add_H: json['hosp_add_H'] ?? '',
      Rem_h: json['Rem_h'] ?? '',
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
    );
  }
}
