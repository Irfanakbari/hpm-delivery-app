import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:get/get.dart';
import 'package:qr_bar_code_scanner_dialog/qr_bar_code_scanner_dialog.dart';
import 'package:status_alert/status_alert.dart';

class Scan extends StatefulWidget {
  const Scan({Key? key}) : super(key: key);

  @override
  State<Scan> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  final _qrBarCodeScannerDialogPlugin = QrBarCodeScannerDialog();
  final storage = const FlutterSecureStorage();
  final dio = Dio();
  RxString qrPcc = "-".obs;
  RxString qrCodeVuteq = "-".obs;
  RxString qrCodeHPM = "-".obs;
  RxString partNo = "-".obs;
  RxString partName = "-".obs;
  RxList riwayat = [].obs;
  RxBool isSubmitDisabled = true.obs;
  RxBool isLoading = false.obs;
  RxBool isRed = false.obs;
  final EventChannel _eventChannel =
      const EventChannel('newland_listenToScanner');
  StreamSubscription? _streamSubscription;

  final Iterable<Duration> pauses = [
    const Duration(milliseconds: 300),
    const Duration(milliseconds: 300),
  ];

  void playBipBipSound() async {
    String bipBipSoundPath =
        "assets/error.mp3"; // Replace this with the path to your bip-bip sound file
    FlutterRingtonePlayer.play(fromAsset: bipBipSoundPath, volume: 0.5);
  }

  void showAlert(String title, String subtitle, Color backgroundColor) {
    if (mounted) {
      StatusAlert.show(
        context,
        duration: const Duration(seconds: 2),
        title: title,
        subtitle: subtitle,
        backgroundColor: backgroundColor,
        titleOptions: StatusAlertTextConfiguration(
          style: const TextStyle(color: Colors.white),
        ),
        subtitleOptions: StatusAlertTextConfiguration(
          style: const TextStyle(color: Colors.white),
        ),
        configuration: const IconConfiguration(
          icon: Icons.error,
          color: Colors.white,
        ),
      );
    }
  }

  void showSuccessAlert(String title, String subtitle, Color backgroundColor) {
    if (mounted) {
      StatusAlert.show(
        context,
        duration: const Duration(seconds: 2),
        title: title,
        subtitle: subtitle,
        backgroundColor: backgroundColor,
        titleOptions: StatusAlertTextConfiguration(
          style: const TextStyle(color: Colors.white),
        ),
        subtitleOptions: StatusAlertTextConfiguration(
          style: const TextStyle(color: Colors.white),
        ),
        configuration: const IconConfiguration(
          icon: Icons.done,
          color: Colors.white,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _streamSubscription =
        _eventChannel.receiveBroadcastStream().listen((value) async {
      try {
        if (qrPcc.value == '-') {
          qrPcc.value = value['barcodeData'];
          await getPCCDetails(qrPcc.value);
        } else if (qrCodeVuteq.value == '-') {
          qrCodeVuteq.value = value['barcodeData'];
          if (qrCodeHPM.value != qrCodeVuteq.value) {
            playBipBipSound();
            Vibrate.vibrateWithPauses(pauses);
            showAlert('Error', 'Part Tag Tidak Sama', Colors.redAccent);
            qrCodeVuteq.value = '-';
            await reportFailed();
          } else if (qrCodeHPM.value == qrCodeVuteq.value) {
            // submitData(qrCode.value);
            isSubmitDisabled.value = false;
          }
        }
      } catch (e) {
        showAlert('Error', 'Kesalahan Pada Scanner', Colors.redAccent);
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    // TODO: implement dispose
    super.dispose();
    riwayat.clear();
  }

  getPCCDetails(kode) async {
    try {
      final cookie = await storage.read(
          key: '@vuteq-token'); // Ubah dengan key cookie yang sesuai
      // Buat header cookie untuk permintaan HTTP
      final headers = {
        'Cookie': cookie != null ? '@vuteq-1-token=$cookie' : '',
      };
      final base = await storage.read(key: '@vuteq-ip');
      var result = await dio.get("http://$base/api/orders/" + kode,
          options: Options(
            headers: headers,
            receiveTimeout: const Duration(milliseconds: 5000),
            sendTimeout: const Duration(milliseconds: 5000),
          ));
      var order = result.data['data'];
      qrCodeHPM.value = order['part_no'].toString();
      partName.value = order['part_name'].toString();
    } catch (e) {
      qrPcc.value = '-';
      qrCodeVuteq.value = '-';
      qrCodeHPM.value = '-';
      showAlert('Error', 'Server tidak merespon permintaan', Colors.redAccent);
    }
  }

  reportFailed() async {
    try {
      final cookie = await storage.read(
          key: '@vuteq-token'); // Ubah dengan key cookie yang sesuai
      // Buat header cookie untuk permintaan HTTP
      final headers = {
        'Cookie': cookie != null ? '@vuteq-1-token=$cookie' : '',
      };
      final Map<String, dynamic> postData = {
        'id_part': qrCodeVuteq.value,
        'pcc': qrPcc.value
      };

      final base = await storage.read(key: '@vuteq-ip');
      await dio.post('http://$base/api/history/failed',
          data: postData,
          options: Options(
            headers: headers,
            receiveTimeout: const Duration(milliseconds: 5000),
            sendTimeout: const Duration(milliseconds: 5000),
          ));

      riwayat.add({"qr": qrPcc.value, "date": DateTime.now()});

      showSuccessAlert('Sukses', 'Data Riwayat Tersimpan', Colors.greenAccent);
    } on DioException catch (e) {
      showAlert('Error', e.response?.data['data'] ?? 'Gagal Menghubungi Server',
          Colors.redAccent);
    } finally {
      qrCodeHPM.value = '-';
      qrCodeVuteq.value = '-';
      qrPcc.value = '-';
    }
  }

  submitData() async {
    if (qrCodeHPM.value == qrCodeVuteq.value) {
      // Ambil cookie dari Flutter Secure Storage
      final cookie = await storage.read(
          key: '@vuteq-token'); // Ubah dengan key cookie yang sesuai
      // Buat header cookie untuk permintaan HTTP
      final headers = {
        'Cookie': cookie != null ? '@vuteq-1-token=$cookie' : '',
      };
      final Map<String, dynamic> postData = {
        'id_part': qrCodeVuteq.value,
        'pcc': qrPcc.value
      };
      try {
        final base = await storage.read(key: '@vuteq-ip');
        await dio.post('http://$base/api/history',
            data: postData,
            options: Options(
              headers: headers,
              receiveTimeout: const Duration(milliseconds: 5000),
              sendTimeout: const Duration(milliseconds: 5000),
            ));

        riwayat.add({"qr": qrPcc.value, "date": DateTime.now()});

        showSuccessAlert(
            'Sukses', 'Data Riwayat Tersimpan', Colors.greenAccent);
        // Reset nilai-nilai
        qrPcc.value = '-';
        qrCodeVuteq.value = '-';
        qrCodeHPM.value = '-';
      } on DioException catch (e) {
        // Kesalahan jaringan
        showAlert(
            'Error',
            e.response?.data['data'] ?? 'Kesalahan Jaringan/Server',
            Colors.redAccent);
        qrPcc.value = '-';
        qrCodeVuteq.value = '-';
        qrCodeHPM.value = '-';
      } finally {
        isSubmitDisabled.value = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text(
            'Scanner Compare',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: Obx(
            () => Container(
              color: isRed.value
                  ? Colors.redAccent
                  : Colors.white, // Warna yang akan berkedip
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Center(
                          child: Text(
                            'PCC Barcode',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          color: Colors.grey,
                          width: double.infinity,
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Text(
                              qrPcc.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'HPM Barcode',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          color: Colors.grey,
                          width: double.infinity,
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Text(
                              qrCodeHPM.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'Vuteq Barcode',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          color: Colors.grey,
                          width: double.infinity,
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Text(
                              qrCodeVuteq.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: () {
                              _qrBarCodeScannerDialogPlugin.getScannedQrBarCode(
                                  context: context,
                                  onCode: (code) async {
                                    if (qrPcc.value == '-') {
                                      qrPcc.value = code!;
                                      await getPCCDetails(qrPcc.value);
                                    } else if (qrCodeVuteq.value == '-') {
                                      qrCodeVuteq.value = code!;
                                      if (qrCodeHPM.value !=
                                          qrCodeVuteq.value) {
                                        playBipBipSound();
                                        Vibrate.vibrateWithPauses(pauses);
                                        showAlert(
                                            'Error',
                                            'Part Tag Tidak Sama',
                                            Colors.redAccent);
                                        await reportFailed();
                                      } else if (qrCodeHPM.value ==
                                          qrCodeVuteq.value) {
                                        // submitData(qrCode.value);
                                        isSubmitDisabled.value = false;
                                      }
                                    }
                                  });
                            },
                            child: const Text("Scan Kamera")),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
                    InkWell(
                        onTap: isSubmitDisabled.value
                            ? null
                            : () async {
                                await submitData();
                              },
                        child: Container(
                          width: Get.width,
                          color:
                              isSubmitDisabled.value ? Colors.grey : Colors.red,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              'Submit',
                              style:
                                  TextStyle(fontSize: 23, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ))
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
