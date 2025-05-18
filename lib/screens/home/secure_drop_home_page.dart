import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';  // Add this import for StreamSubscription
import 'widgets/control_card.dart';
import 'widgets/small_info_card.dart';
import '../../utils/date_utils.dart';

class SecureDropHomePage extends StatefulWidget {
  const SecureDropHomePage({super.key});

  @override
  _SecureDropHomePageState createState() => _SecureDropHomePageState();
}

class _SecureDropHomePageState extends State<SecureDropHomePage> {
  bool parcelDetected = false;
  bool boxOpen = false;
  bool autoDetect = true;
  bool photoTaken = false;
  bool securityMonitoring = false; // Security monitoring state
  bool cashVaultStatus = false; // Using cashVaultStatus instead of paymentActive

  // Added variable to track previous parcel state for detecting changes
  bool _previousParcelState = false;

  // Variables for security monitoring
  StreamSubscription<DatabaseEvent>? _securityMonitoringSubscription;
  bool _securityMessageShown = false;

  // Timer for camera auto-timeout
  DateTime? photoStartTime;

  // Timer for cash vault status timeout
  Timer? _cashVaultTimer;

  // Variables to store latest image information
  String latestImagePath = '';
  String latestImageTimestamp = '';
  String? latestImageBase64;

  // List to store recent image information
  List<Map<String, dynamic>> recentImages = [];

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Image selection variables
  bool isSelectMode = false;
  Set<int> selectedImageIndices = {};

  @override
  void initState() {
    super.initState();

    // Fetch images when app starts
    _fetchRecentImages();

    // Set up a listener for the SecureDrop status from Firebase
    _database.child('SecureDrop').onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          parcelDetected = data['parcelDetected'] ?? false;
          boxOpen = data['boxOpen'] ?? false;
          autoDetect = data['autoDetect'] ?? true;
          photoTaken = data['photoTaken'] ?? false;
          securityMonitoring = data['securityMonitoring'] ?? false;
          cashVaultStatus = data['cashVaultStatus'] ?? false;

          // Handle parcel state change if security monitoring is active
          if (securityMonitoring && parcelDetected && !_previousParcelState && !_securityMessageShown) {
            _securityMessageShown = true;
            _takeMultipleSecurityPhotos();
          }
          _previousParcelState = parcelDetected;
        });
      }
    });

    // Check for latestImage in Firebase and load it
    _database.child('SecureDrop/latestImage').get().then((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          latestImagePath = data['path'] ?? '';
          latestImageTimestamp = data['timestamp'] ?? '';
          if (latestImagePath.isNotEmpty) {
            _fetchLatestImage();
          }
        });
      }
    }).catchError((error) {
      debugPrint('Error fetching latest image info: $error');
    });

    // Start camera timeout checker
    _checkCameraTimeout();
  }

  @override
  void dispose() {
    // Cancel any active subscription when the widget is disposed
    _securityMonitoringSubscription?.cancel();
    _cashVaultTimer?.cancel();
    super.dispose();
  }

  // Toggle security monitoring and auto detect together
  void _toggleSecurityAndAutoDetect() {
    setState(() {
      // Toggle both features together
      securityMonitoring = !securityMonitoring;
      autoDetect = securityMonitoring; // Match autoDetect to securityMonitoring

      if (securityMonitoring) {
        // If security is turned on and a parcel is already detected, take photos immediately
        if (parcelDetected) {
          _securityMessageShown = true; // Set this to true to prevent duplicate photos
          _takeMultipleSecurityPhotos();
        } else {
          // Otherwise, show waiting message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Auto detection activated: Waiting for parcel detection...",
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.blue[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          _securityMessageShown = false;
        }
      } else {
        // Cancel monitoring when turned off
        _securityMonitoringSubscription?.cancel();
        _securityMonitoringSubscription = null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Auto detect deactivated",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Update database with new state
      _updateDatabase();
    });
  }

  // Method to activate cash vault
  void _activateCashVault() {
    setState(() {
      cashVaultStatus = true;
      _updateDatabase();

      // Show notification for cash vault activation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Cash Vault unlocked for 10 seconds...",
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Cancel existing timer if it exists
      _cashVaultTimer?.cancel();

      // Set timer to deactivate cash vault after 5 seconds
      _cashVaultTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            cashVaultStatus = false;
            _updateDatabase();

            // Show notification for cash vault locking
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Cash Vault locked",
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.grey[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          });
        }
      });
    });
  }

  // New method to take multiple security photos
  void _takeMultipleSecurityPhotos() {
    // Take first photo immediately
    setState(() {
      photoTaken = true;
      photoStartTime = DateTime.now();
      _updateDatabase(takePhoto: true);
    });

    // Show notification for first photo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Parcel detected: Taking picture...",
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Schedule second photo after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          photoTaken = true;
          photoStartTime = DateTime.now();
          _updateDatabase(takePhoto: true);
        });

        // Schedule third photo after another 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              photoTaken = true;
              photoStartTime = DateTime.now();
              _updateDatabase(takePhoto: true);
            });

            // Notify completion
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Detected parcel: Photo taken successfully",
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });
      }
    });
  }

  // Method to take security photos
  void _takeSecurityPhoto(String notificationMessage) {
    setState(() {
      photoTaken = true;
      photoStartTime = DateTime.now();
      _updateDatabase(takePhoto: true);
    });

    // Show notification that a security photo was taken
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationMessage,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    // After taking a photo, update the main status image
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _fetchRecentImages().then((_) {
          if (recentImages.isNotEmpty) {
            setState(() {
              latestImagePath = recentImages[0]['path'];
              latestImageTimestamp = recentImages[0]['timestamp'];
            });
            _fetchLatestImage();
          }
        });
      }
    });
  }

  // Method to check camera timeout and schedule next check
  void _checkCameraTimeout() {
    if (photoTaken && photoStartTime != null) {
      // Check if 30 seconds have passed
      if (DateTime.now().difference(photoStartTime!).inSeconds > 30) {
        // Auto-disable camera
        setState(() {
          photoTaken = false;
          photoStartTime = null;
          _updateDatabase();
        });
      }
    }

    // Schedule next check in 1 second
    if (mounted) {
      Future.delayed(const Duration(seconds: 1), _checkCameraTimeout);
    }
  }

  // Method to fetch the latest image
  Future<void> _fetchLatestImage() async {
    if (latestImagePath.isEmpty) return;

    try {
      final snapshot = await _database.child('$latestImagePath').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          latestImageBase64 = data['image'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching latest image: $e');
    }
  }

  // Method to fetch recent images from Firebase
  Future<void> _fetchRecentImages() async {
    try {
      // Query the Image path in Firebase
      final snapshot = await _database.child('Image').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> datesMap = snapshot.value as Map;
        List<Map<String, dynamic>> allImages = [];

        // Iterate through dates
        datesMap.forEach((dateKey, dateData) {
          final Map<dynamic, dynamic> imagesMap = dateData as Map;

          // Iterate through images for each date
          imagesMap.forEach((timeKey, imageData) {
            // Extract the extension (e.g., .json)
            String timeKeyStr = timeKey.toString();
            String timeWithoutExt =
            timeKeyStr.contains('.')
                ? timeKeyStr.substring(0, timeKeyStr.lastIndexOf('.'))
                : timeKeyStr;

            // Add image data to the list
            allImages.add({
              'path': 'Image/$dateKey/$timeKey',
              'timestamp': '$dateKey $timeWithoutExt',
              'dateStr': dateKey,
              'timeStr': timeWithoutExt,
            });
          });
        });

        // Sort images by timestamp (newest first)
        allImages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        // Take the 10 most recent images
        setState(() {
          recentImages = allImages.take(10).toList();

          // Clear selection when refreshing images
          isSelectMode = false;
          selectedImageIndices.clear();

          // If the latest image path is empty but we have recent images,
          // then the first image should be set as the main image
          if (latestImagePath.isEmpty && allImages.isNotEmpty) {
            latestImagePath = allImages[0]['path'];
            latestImageTimestamp = allImages[0]['timestamp'];
            _fetchLatestImage();

            // Also update in database
            _database.child('SecureDrop/latestImage').update({
              'path': latestImagePath,
              'timestamp': latestImageTimestamp,
            });
          }
        });
      } else {
        // No images exist
        setState(() {
          recentImages = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent images: $e');
    }
  }

  void _updateDatabase({bool takePhoto = false}) {
    _database
        .child('SecureDrop')
        .update({
      'parcelDetected': parcelDetected,
      'boxOpen': boxOpen,
      'autoDetect': autoDetect,
      'photoTaken': takePhoto ? true : photoTaken,
      'securityMonitoring': securityMonitoring,
      'cashVaultStatus': cashVaultStatus, // Updated to use cashVaultStatus
    })
        .then((_) {
      if (takePhoto) {
        // Set the start time for photo taking
        photoStartTime = DateTime.now();

        // After taking a photo, wait for it to be saved and then refresh
        Future.delayed(const Duration(seconds: 5), () {
          // Fetch the most recent images
          _fetchRecentImages().then((_) {
            // If there are images, update the latest image
            if (recentImages.isNotEmpty) {
              setState(() {
                latestImagePath = recentImages[0]['path'];
                latestImageTimestamp = recentImages[0]['timestamp'];
              });

              // Update the latest image in the database and fetch its data
              _database.child('SecureDrop/latestImage').update({
                'path': latestImagePath,
                'timestamp': latestImageTimestamp,
              }).then((_) {
                _fetchLatestImage();
              });
            }
          });
        });
      }
    });
  }

  // Delete selected images from Firebase
  Future<void> _deleteSelectedImages() async {
    try {
      // First confirm with user
      bool confirm =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
              title: Text(
                'Delete ${selectedImageIndices.length} Image${selectedImageIndices.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Text(
                'Are you sure you want to delete ${selectedImageIndices.length > 1 ? 'these images' : 'this image'}?',
                style: GoogleFonts.poppins(),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ) ??
              false;

      if (!confirm) return;

      // Convert to list and sort in descending order to safely remove items by index
      List<int> sortedIndices =
      selectedImageIndices.toList()..sort((a, b) => b.compareTo(a));

      // Keep track of whether we've deleted the main image
      bool deletedMainImage = false;
      List<String> imagesToDelete = [];

      // Collect all images to delete
      for (int index in sortedIndices) {
        if (index < recentImages.length) {
          final imagePath = recentImages[index]['path'];
          imagesToDelete.add(imagePath);

          if (imagePath == latestImagePath) {
            deletedMainImage = true;
          }
        }
      }

      // Delete all selected images from Firebase
      for (String path in imagesToDelete) {
        await _database.child(path).remove();
      }

      // If the main image was deleted, update it
      if (deletedMainImage) {
        // Create a list of remaining images by filtering out the selected ones
        List<Map<String, dynamic>> remainingImages = List.from(recentImages);

        // Remove the deleted images from our local copy
        // Sort indices in descending order to avoid index shifting issues
        for (int index in sortedIndices) {
          if (index < remainingImages.length) {
            remainingImages.removeAt(index);
          }
        }

        if (remainingImages.isNotEmpty) {
          // Set the first remaining image as main
          setState(() {
            latestImagePath = remainingImages[0]['path'];
            latestImageTimestamp = remainingImages[0]['timestamp'];
            _fetchLatestImage();
          });

          // Update in database
          _database.child('SecureDrop/latestImage').update({
            'path': latestImagePath,
            'timestamp': latestImageTimestamp,
          });
        } else {
          // No more images, reset
          setState(() {
            latestImagePath = '';
            latestImageTimestamp = '';
            latestImageBase64 = null;
          });

          // Clear in database
          _database.child('SecureDrop/latestImage').remove();
        }
      }

      // Refresh the list and exit selection mode
      setState(() {
        isSelectMode = false;
        selectedImageIndices.clear();
      });
      _fetchRecentImages();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${imagesToDelete.length} image${imagesToDelete.length > 1 ? 's' : ''} deleted successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('Error deleting images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete images',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              pinned: false,
              snap: false,
              expandedHeight: 90,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF6C63FF),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SecureDrop',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D1F2B),
                                ),
                              ),
                              Text(
                                'Secure parcel delivery',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Status Card
                    Container(
                      width: double.infinity,
                      height: 240,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        image:
                        latestImageBase64 != null
                            ? DecorationImage(
                          image: MemoryImage(
                            base64Decode(latestImageBase64!),
                          ),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.6],
                              ),
                            ),
                          ),

                          // Content overlay
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color:
                                              parcelDetected
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'STATUS',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        latestImageTimestamp.isNotEmpty
                                            ? latestImageTimestamp
                                            : '${DateTime.now().day} ${getMonth(DateTime.now().month)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Status text
                                if (parcelDetected)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Parcel Detected',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              'Ready for collection',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                fontSize: 8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                            boxOpen
                                                ? Colors.green.withOpacity(
                                              0.3,
                                            )
                                                : const Color(
                                              0xFF6C63FF,
                                            ).withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            boxOpen
                                                ? Icons.lock_open
                                                : Icons.lock,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              boxOpen
                                                  ? 'Box Unlocked'
                                                  : 'Box Secured',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              boxOpen
                                                  ? 'Access granted'
                                                  : 'Waiting for delivery',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                fontSize: 8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                // Bottom status indicators
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatusIndicator(
                                      value: autoDetect ? 'ON' : 'OFF',
                                      label: 'Auto Detect',
                                      iconData: Icons.sensors,
                                      isActive: autoDetect,
                                    ),
                                    _buildStatusIndicator(
                                      value: photoTaken ? 'ACTIVE' : 'OFF',
                                      label: 'Camera',
                                      iconData: Icons.camera_alt,
                                      isActive: photoTaken,
                                    ),
                                    _buildStatusIndicator(
                                      value: boxOpen ? 'UNLOCKED' : 'LOCKED',
                                      label: 'Box Status',
                                      iconData:
                                      boxOpen
                                          ? Icons.lock_open
                                          : Icons.lock,
                                      isActive: !boxOpen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Control Area Title
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Quick Controls',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D1F2B),
                        ),
                      ),
                    ),

                    // Control Cards Row (fix overflow and spacing)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width:
                          (MediaQuery.of(context).size.width - 56) /
                              2, // 20+20 padding + 12 spacing
                          child: _buildControlCard(
                            title: 'Box Control',
                            subtitle: boxOpen ? 'Tap to Lock' : 'Tap to Unlock',
                            iconData: boxOpen ? Icons.lock_open : Icons.lock,
                            isActive: boxOpen,
                            color:
                            boxOpen
                                ? Colors.green
                                : const Color(0xFF6C63FF),
                            onTap: () {
                              setState(() {
                                boxOpen = !boxOpen;
                                _updateDatabase();
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 56) / 2,
                          child: _buildControlCard(
                            title: 'Camera',
                            subtitle:
                            photoTaken ? 'Recording...' : 'Tap to Activate',
                            iconData: Icons.camera_alt,
                            isActive: photoTaken,
                            color:
                            photoTaken
                                ? Colors.amber
                                : const Color(0xFF6C63FF),
                            onTap:
                            boxOpen
                                ? () {
                              setState(() {
                                photoTaken = !photoTaken;
                                if (photoTaken) {
                                  photoStartTime = DateTime.now();
                                } else {
                                  photoStartTime = null;
                                }
                                _updateDatabase(takePhoto: photoTaken);
                              });
                            }
                                : null,
                            isLocked: !boxOpen,
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 56) / 2,
                          child: _buildControlCard(
                            title: 'Auto Detect',  // Combined card
                            subtitle: securityMonitoring ? 'Enabled' : 'Tap to Enable',
                            iconData: securityMonitoring ? Icons.security : Icons.sensors,
                            isActive: securityMonitoring,
                            color: securityMonitoring ? Colors.blue[600]! : const Color(0xFF6C63FF),
                            onTap: _toggleSecurityAndAutoDetect,  // Combined function
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 56) / 2,
                          child: _buildControlCard(
                            title: 'Cash Vault',  // Updated to Cash Vault
                            subtitle: cashVaultStatus ? 'Unlocked' : 'Tap to Unlock (10s)',
                            iconData: Icons.account_balance_wallet,  // Changed icon to wallet
                            isActive: cashVaultStatus,
                            color: cashVaultStatus ? Colors.green[600]! : const Color(0xFF6C63FF),
                            onTap: cashVaultStatus ? null : _activateCashVault,  // Disable when already active
                          ),
                        ),
                      ],
                    ),

                    // Recent Images Header
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D1F2B),
                            ),
                          ),
                          Row(
                            children: [
                              if (isSelectMode) ...[
                                Text(
                                  '${selectedImageIndices.length} selected',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                  selectedImageIndices.isNotEmpty
                                      ? _deleteSelectedImages
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.black,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isSelectMode = false;
                                      selectedImageIndices.clear();
                                    });
                                  },
                                ),
                              ] else if (recentImages.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    // Refresh images
                                    _fetchRecentImages();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(
                                    'Refresh',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF6C63FF),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Recent Images List
                    _buildRecentImagesList(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required String value,
    required String label,
    required IconData iconData,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
              isActive
                  ? Colors.greenAccent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required String subtitle,
    required IconData iconData,
    required bool isActive,
    required Color color,
    required VoidCallback? onTap, // Make nullable
    bool isLocked = false, // Add this parameter
  }) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0), // Slightly reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(height: 12), // Reduced spacing
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1F2B),
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Toggle switch inside the card
                  Align(
                    alignment: Alignment.centerRight,
                    child: Switch(
                      value: isActive,
                      onChanged:
                      isLocked || onTap == null ? null : (val) => onTap(),
                      activeColor: color,
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Locked overlay
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Icon(Icons.lock, color: Colors.grey[500], size: 32),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentImagesList() {
    if (recentImages.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No recent images available',
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentImages.length,
        itemBuilder: (context, index) {
          final imageData = recentImages[index];
          final bool isSelected = selectedImageIndices.contains(index);

          return FutureBuilder(
            future: _getImageBase64(imageData['path']),
            builder: (context, snapshot) {
              // Loading state - show placeholder that will be automatically replaced
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              }

              // Error state
              if (snapshot.hasError || !snapshot.hasData) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red[400],
                      size: 30,
                    ),
                  ),
                );
              }

              final base64Str = snapshot.data as String;

              return GestureDetector(
                onTap: () {
                  if (isSelectMode) {
                    // In select mode, tap toggles selection
                    setState(() {
                      if (isSelected) {
                        selectedImageIndices.remove(index);
                      } else {
                        selectedImageIndices.add(index);
                      }
                    });
                  } else {
                    // Show full screen image
                    _showFullScreenImage(
                      context,
                      base64Str,
                      imageData['timestamp'],
                    );
                  }
                },
                onLongPress: () {
                  // Enter selection mode on long press
                  setState(() {
                    isSelectMode = true;
                    selectedImageIndices.add(index);
                  });
                },
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border:
                        isSelected
                            ? Border.all(
                          color: const Color(0xFF6C63FF),
                          width: 3,
                        )
                            : (imageData['path'] == latestImagePath
                            ? Border.all(
                          color: const Color(0xFF6C63FF),
                          width: 2,
                        )
                            : null),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(base64Str)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Time overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                imageData['timestamp'],
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (imageData['path'] == latestImagePath &&
                                !isSelected)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6C63FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Selection indicator
                    if (isSelected)
                      Positioned(
                        top: 10,
                        right: 26,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getImageBase64(String path) async {
    try {
      final snapshot = await _database.child(path).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        return data['image'] as String;
      }
      throw Exception('Image not found');
    } catch (e) {
      debugPrint('Error fetching image data: $e');
      throw Exception('Failed to load image');
    }
  }

  void _showFullScreenImage(
      BuildContext context,
      String base64Image,
      String timestamp,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageViewer(
          imageBase64: base64Image,
          timestamp: timestamp,
        ),
      ),
    );
  }
}

// Full screen image viewer widget
class FullScreenImageViewer extends StatelessWidget {
  final String imageBase64;
  final String timestamp;

  const FullScreenImageViewer({
    Key? key,
    required this.imageBase64,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          timestamp,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share, color: Colors.white),
            ),
            onPressed: () {
              // Add share functionality
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(base64Decode(imageBase64), fit: BoxFit.contain),
        ),
      ),
    );
  }
}