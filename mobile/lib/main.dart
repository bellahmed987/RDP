import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core/api.dart';

void main() => runApp(const RdpApp());

class RdpApp extends StatelessWidget {
  const RdpApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ShareKind',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b55)),
      useMaterial3: true,
    ),
    home: const Gate(),
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Map<String, dynamic>? user;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await Api.instance.restore();
      user = await Api.instance.me();
      Api.instance.role = user?['role']?.toString();
    } catch (_) {
      await Api.instance.setToken(null);
    }
    if (mounted) setState(() => loading = false);
  }

  void signedIn(Map<String, dynamic> u) => setState(() {
    user = u;
    Api.instance.role = u['role']?.toString();
  });
  Future<void> signOut() async {
    await Api.instance.setToken(null);
    Api.instance.role = null;
    setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : user == null
      ? AuthScreen(onSignedIn: signedIn)
      : Home(user: user!, onSignOut: signOut);
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      city = TextEditingController();
  String role = 'RECIPIENT';
  bool register = false, busy = false;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = register
          ? await Api.instance.register(
              name.text,
              email.text,
              password.text,
              role,
              city.text,
            )
          : await Api.instance.login(email.text, password.text);
      await Api.instance.setToken(res['token']);
      widget.onSignedIn(Map<String, dynamic>.from(res['user']));
    } on DioException catch (e) {
      setState(
        () => error = e.response?.data is Map
            ? e.response!.data['message']?.toString() ?? 'Check your details.'
            : 'Cannot reach the server. Start the backend and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.volunteer_activism,
                  size: 64,
                  color: Color(0xff176b55),
                ),
                Text(
                  'ShareKind',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const Text(
                  'Good things find good people.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (register) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  DropdownButtonFormField(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Account type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'RECIPIENT',
                        child: Text('Recipient'),
                      ),
                      DropdownMenuItem(value: 'DONOR', child: Text('Donor')),
                    ],
                    onChanged: (v) => setState(() => role = v ?? role),
                  ),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (10+ characters)',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : register
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    register = !register;
                    error = null;
                  }),
                  child: Text(register ? 'Sign in' : 'Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.user, required this.onSignOut});
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  final myDonationsKey = GlobalKey<_DonationListState>();
  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'];
    final donor = role == 'DONOR', admin = role == 'ADMIN';
    final labels = admin
        ? ['Overview', 'Users', 'Donations', 'Reports']
        : donor
        ? ['Donations', 'Requests', 'Profile']
        : ['Explore', 'Requests', 'Favorites', 'For you', 'Profile'];
    final pages = admin
        ? [
            const AdminPage(),
            const UsersPage(),
            const AdminDonationsPage(),
            const AdminReportsPage(),
          ]
        : donor
        ? [
            DonationList(mine: true, key: myDonationsKey),
            const RequestList(incoming: true),
            ProfilePage(user: widget.user),
          ]
        : [
            const DonationList(mine: false),
            const RequestList(incoming: false),
            const FavoritesPage(),
            const RecsPage(),
            ProfilePage(user: widget.user),
          ];
    final icons = admin
        ? [Icons.dashboard, Icons.people, Icons.inventory_2, Icons.flag]
        : donor
        ? [Icons.inventory_2, Icons.inbox, Icons.person]
        : [
            Icons.explore,
            Icons.inbox,
            Icons.favorite,
            Icons.auto_awesome,
            Icons.person,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text('ShareKind · ${labels[index]}'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'ShareKind help',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const HelpDialog(),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          if (donor && index == 0)
            IconButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DonationForm(
                  onSaved: () => myDonationsKey.currentState?.refresh(),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}

class DonationList extends StatefulWidget {
  const DonationList({super.key, required this.mine});
  final bool mine;
  @override
  State<DonationList> createState() => _DonationListState();
}

class _DonationListState extends State<DonationList> {
  final search = TextEditingController();
  String? category;
  double? nearbyLatitude, nearbyLongitude;
  double nearbyRadius = 5;
  late Future<dynamic> future;
  static const cats = [
    'FOOD',
    'CLOTHING',
    'ELECTRONICS',
    'BOOKS',
    'FURNITURE',
    'TOYS',
    'HOUSEHOLD',
    'OTHER',
  ];
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async {
    final r = widget.mine
        ? await Api.instance.dio.get('/donations/mine')
        : nearbyLatitude != null && nearbyLongitude != null
        ? await Api.instance.dio.get(
            '/donations/nearby',
            queryParameters: {
              'latitude': nearbyLatitude,
              'longitude': nearbyLongitude,
              'radiusKm': nearbyRadius,
              if (category != null) 'category': category,
            },
          )
        : await Api.instance.dio.get(
            '/donations',
            queryParameters: {
              if (search.text.isNotEmpty) 'q': search.text,
              if (category != null) 'category': category,
            },
          );
    return r.data;
  }

  void refresh() => setState(() => future = load());
  Future<void> chooseNearby() async {
    final lat = TextEditingController(text: nearbyLatitude?.toString() ?? '');
    final lon = TextEditingController(text: nearbyLongitude?.toString() ?? '');
    final radius = TextEditingController(text: nearbyRadius.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nearby resources'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your current coordinates. The app sends these to the server to find items within your radius.',
            ),
            TextField(
              controller: lat,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            TextField(
              controller: lon,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            TextField(
              controller: radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius in km (up to 100)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Find nearby'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;
    final parsedLat = double.tryParse(lat.text),
        parsedLon = double.tryParse(lon.text),
        parsedRadius = double.tryParse(radius.text);
    if (parsedLat == null ||
        parsedLon == null ||
        parsedRadius == null ||
        parsedLat < -90 ||
        parsedLat > 90 ||
        parsedLon < -180 ||
        parsedLon > 180 ||
        parsedRadius <= 0 ||
        parsedRadius > 100) {
      snack(context, 'Enter valid coordinates and a radius up to 100 km.');
      return;
    }
    setState(() {
      nearbyLatitude = parsedLat;
      nearbyLongitude = parsedLon;
      nearbyRadius = parsedRadius;
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!widget.mine)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: search,
                onSubmitted: (_) => refresh(),
                decoration: InputDecoration(
                  hintText: 'Search resources',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: refresh,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              Row(
                children: [
                  DropdownButton<String?>(
                    value: category,
                    hint: const Text('All categories'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...cats.map(
                        (x) =>
                            DropdownMenuItem(value: x, child: Text(pretty(x))),
                      ),
                    ],
                    onChanged: (v) {
                      category = v;
                      refresh();
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: nearbyLatitude == null
                        ? chooseNearby
                        : () {
                            setState(() {
                              nearbyLatitude = null;
                              nearbyLongitude = null;
                              future = load();
                            });
                          },
                    icon: Icon(
                      nearbyLatitude == null
                          ? Icons.near_me_outlined
                          : Icons.clear,
                    ),
                    label: Text(
                      nearbyLatitude == null ? 'Nearby' : 'Clear nearby',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      Expanded(
        child: FutureBuilder<dynamic>(
          future: future,
          builder: (c, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return ErrorPane(onRetry: refresh);
            final data = s.data;
            final List items = data is List
                ? data
                : (data is Map ? data['items'] ?? [] : []);
            if (items.isEmpty) {
              return EmptyPane(
                title: widget.mine ? 'No donations yet' : 'No resources found',
                subtitle: widget.mine
                    ? 'Tap + to publish one.'
                    : 'Try another search.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: items
                    .map(
                      (x) => DonationCard(item: Map<String, dynamic>.from(x)),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class DonationCard extends StatefulWidget {
  const DonationCard({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  State<DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<DonationCard> {
  bool favorite = false, savingFavorite = false;
  Map<String, dynamic> get item => widget.item;
  @override
  void initState() {
    super.initState();
    favorite = item['favorite'] == true;
  }

  Future<void> toggleFavorite() async {
    if (savingFavorite) return;
    setState(() => savingFavorite = true);
    try {
      final path = '/favorites/${item['id']}';
      if (favorite) {
        await Api.instance.dio.delete(path);
      } else {
        await Api.instance.dio.post(path);
      }
      if (mounted) setState(() => favorite = !favorite);
    } on DioException catch (e) {
      if (mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not update saved items.',
        );
      }
    } finally {
      if (mounted) setState(() => savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism, color: Color(0xff176b55)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['title'] ?? 'Donation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(pretty(item['status'] ?? 'AVAILABLE')),
              if (Api.instance.role == 'RECIPIENT')
                IconButton(
                  tooltip: favorite ? 'Remove saved item' : 'Save item',
                  onPressed: savingFavorite ? null : toggleFavorite,
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? Colors.red : null,
                  ),
                ),
            ],
          ),
          ..._donationPhotoStrip(item),
          Text(
            '${pretty(item['category'] ?? '')} · ${item['quantity'] ?? 1} available',
          ),
          Text(
            '${item['city'] ?? item['donorCity'] ?? 'Location not set'} · ${item['donorName'] ?? ''}',
          ),
          Text(
            item['description'] ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (item['latitude'] != null && item['longitude'] != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DonationMap(item: item),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Pickup map'),
              ),
            ),
          if (item['status'] == 'AVAILABLE')
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => request(context),
                child: const Text('Request item'),
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> request(BuildContext context) async {
    final qty = TextEditingController(text: '1'), msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Request item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: msg,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.dio.post(
        '/donations/${item['id']}/requests',
        data: {'quantity': int.tryParse(qty.text) ?? 1, 'message': msg.text},
      );
      if (context.mounted) snack(context, 'Request sent.');
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Request could not be sent.',
        );
      }
    }
  }
}

List<Widget> _donationPhotoStrip(Map<String, dynamic> item) {
  final paths = (item['imageUrls'] as List? ?? []).whereType<String>().toList();
  if (paths.isEmpty) return const [];
  final baseUri = Uri.parse(Api.instance.dio.options.baseUrl);
  return [
    const SizedBox(height: 12),
    SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            baseUri.resolve(paths[index]).toString(),
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 200,
              height: 150,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    ),
  ];
}

class DonationForm extends StatefulWidget {
  const DonationForm({super.key, this.onSaved});
  final VoidCallback? onSaved;
  @override
  State<DonationForm> createState() => _DonationFormState();
}

class _DonationFormState extends State<DonationForm> {
  final title = TextEditingController(),
      description = TextEditingController(),
      qty = TextEditingController(text: '1'),
      address = TextEditingController(),
      city = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  final Set<String> uploadedPhotoPaths = {};
  final List<XFile> photos = [];
  String cat = 'FOOD', condition = 'GOOD';
  bool busy = false;
  int? createdDonationId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      createdDonationId == null ? 'Share a resource' : 'Finish photo upload',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField(
              initialValue: cat,
              items: donationCategories
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text(pretty(x))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => cat = v!),
            ),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Product photos (${photos.length}/5)')),
                TextButton.icon(
                  onPressed: busy || createdDonationId != null
                      ? null
                      : pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add photos'),
                ),
              ],
            ),
            if (photos.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(photos.length, (index) {
                  final photo = photos[index];
                  return InputChip(
                    avatar: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(photo.path),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    label: Text('Photo ${index + 1}'),
                    onDeleted: busy || createdDonationId != null
                        ? null
                        : () => setState(() => photos.removeAt(index)),
                  );
                }),
              ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PNG or JPEG, up to 8 MB each. Maximum 5 photos.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            DropdownButtonFormField(
              initialValue: condition,
              items: const ['NEW', 'LIKE_NEW', 'GOOD', 'FAIR', 'NEEDS_REPAIR']
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text(pretty(x))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => condition = v!),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Pickup address'),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(
          busy
              ? (createdDonationId == null ? 'Publishing…' : 'Uploading…')
              : (createdDonationId == null ? 'Publish' : 'Retry photo upload'),
        ),
      ),
    ],
  );

  Future<void> pickPhotos() async {
    final remaining = 5 - photos.length;
    if (remaining <= 0) {
      snack(context, 'A donation can have up to 5 photos.');
      return;
    }
    try {
      final picked = await imagePicker.pickMultiImage(
        limit: remaining,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted || picked.isEmpty) return;
      final accepted = picked.take(remaining).toList();
      final supported = accepted.where((photo) {
        final extension = photo.name.toLowerCase().split('.').last;
        return extension == 'png' || extension == 'jpg' || extension == 'jpeg';
      }).toList();
      setState(() => photos.addAll(supported));
      if (supported.length != accepted.length) {
        snack(context, 'Only PNG and JPEG photos are supported.');
      }
      if (picked.length > remaining) {
        snack(context, 'Only five photos can be added to one donation.');
      }
    } catch (_) {
      if (mounted) snack(context, 'Could not open the photo picker.');
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (createdDonationId == null) {
        final response = await Api.instance.dio.post(
          '/donations',
          data: {
            'title': title.text,
            'category': cat,
            'description': description.text,
            'condition': condition,
            'quantity': int.tryParse(qty.text) ?? 1,
            'pickupAddress': address.text,
            'city': city.text,
          },
        );
        final id = (response.data as Map<String, dynamic>)['id'];
        if (id is! int) throw StateError('The donation was not returned.');
        if (mounted) setState(() => createdDonationId = id);
      }
      await uploadPhotos();
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              (createdDonationId == null
                  ? 'Check required fields.'
                  : 'Donation posted, but a photo could not be uploaded. Tap Retry photo upload.'),
        );
      }
    } on StateError catch (e) {
      if (mounted) snack(context, e.message.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uploadPhotos() async {
    final donationId = createdDonationId;
    if (donationId == null) return;
    for (final photo in photos) {
      if (uploadedPhotoPaths.contains(photo.path)) continue;
      final extension = photo.name.toLowerCase().split('.').last;
      final subtype = switch (extension) {
        'png' => 'png',
        'jpg' || 'jpeg' => 'jpeg',
        _ => null,
      };
      if (subtype == null) {
        throw StateError('Please choose PNG or JPEG photos.');
      }
      await Api.instance.dio.post(
        '/donations/$donationId/images',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            photo.path,
            filename: photo.name,
            contentType: DioMediaType('image', subtype),
          ),
        }),
      );
      uploadedPhotoPaths.add(photo.path);
    }
  }
}

const donationCategories = [
  'FOOD',
  'CLOTHING',
  'ELECTRONICS',
  'BOOKS',
  'FURNITURE',
  'TOYS',
  'HOUSEHOLD',
  'OTHER',
];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  WebSocketChannel? channel;
  bool connected = false;
  String? error;
  int get conversationId => widget.conversation['id'] as int;
  @override
  void initState() {
    super.initState();
    load();
    connect();
  }

  Future<void> load() async {
    try {
      final response = await Api.instance.dio.get(
        '/conversations/$conversationId/messages',
      );
      if (mounted) {
        setState(
          () => messages
            ..clear()
            ..addAll(
              (response.data as List).map((x) => Map<String, dynamic>.from(x)),
            ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => error =
              e.response?.data?['message']?.toString() ??
              'Could not load chat history.',
        );
      }
    }
  }

  Future<void> connect() async {
    try {
      final base = Uri.parse(Api.instance.dio.options.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws',
        query: null,
      );
      final socket = WebSocketChannel.connect(uri);
      channel = socket;
      await socket.ready;
      final auth =
          Api.instance.dio.options.headers['Authorization']?.toString() ?? '';
      socket.sink.add(
        'CONNECT\naccept-version:1.2\nhost:${uri.host}\nAuthorization:$auth\n\n\u0000',
      );
      socket.stream.listen(
        (frame) {
          final text = frame.toString();
          if (text.startsWith('CONNECTED')) {
            socket.sink.add(
              'SUBSCRIBE\nid:rdp-$conversationId\ndestination:/topic/conversations/$conversationId\nack:auto\n\n\u0000',
            );
            if (mounted) setState(() => connected = true);
          } else if (text.startsWith('MESSAGE')) {
            final split = text.indexOf('\n\n');
            if (split < 0) return;
            final body = text
                .substring(split + 2)
                .replaceAll('\u0000', '')
                .trim();
            try {
              final item = Map<String, dynamic>.from(jsonDecode(body));
              if (mounted) setState(() => messages.add(item));
            } catch (_) {}
          } else if (text.startsWith('ERROR') && mounted) {
            setState(() => error = 'Chat connection rejected. Sign in again.');
          }
        },
        onError: (_) {
          if (mounted) setState(() => connected = false);
        },
        onDone: () {
          if (mounted) setState(() => connected = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => connected = false);
    }
  }

  void send() {
    final body = input.text.trim();
    if (body.isEmpty || !connected) return;
    channel?.sink.add(
      'SEND\ndestination:/app/chat/$conversationId\ncontent-type:application/json\n\n${jsonEncode({'body': body})}\u0000',
    );
    input.clear();
  }

  @override
  void dispose() {
    channel?.sink.close();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conversation['otherUserName']?.toString() ?? 'Chat'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(24),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            connected ? 'Live chat connected' : 'Connecting to live chat…',
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [TextButton(onPressed: load, child: const Text('Retry'))],
          ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            children: messages
                .map(
                  (m) => Align(
                    alignment: Alignment.centerLeft,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['senderName']?.toString() ?? 'Participant',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(m['body']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: connected ? send : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class DonationMap extends StatelessWidget {
  const DonationMap({super.key, required this.item});
  final Map<String, dynamic> item;
  static const enabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');
  @override
  Widget build(BuildContext context) {
    final point = LatLng(
      (item['latitude'] as num).toDouble(),
      (item['longitude'] as num).toDouble(),
    );
    return AlertDialog(
      title: Text(item['title']?.toString() ?? 'Pickup location'),
      content: SizedBox(
        width: 500,
        height: 380,
        child: enabled
            ? GoogleMap(
                initialCameraPosition: CameraPosition(target: point, zoom: 14),
                markers: {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: point,
                    infoWindow: InfoWindow(title: item['title']?.toString()),
                  ),
                },
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 48),
                    const Text('Add a Google Maps key to enable the map.'),
                    Text(
                      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class RequestList extends StatefulWidget {
  const RequestList({super.key, required this.incoming});
  final bool incoming;
  @override
  State<RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<RequestList> {
  late Future<dynamic> future;
  final Set<dynamic> ratedRequests = {};
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async => (await Api.instance.dio.get(
    widget.incoming ? '/requests/incoming' : '/requests/mine',
  )).data;
  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = s.data as List;
      if (rows.isEmpty) {
        return const EmptyPane(
          title: 'No requests',
          subtitle: 'Requests appear here.',
        );
      }
      return ListView(
        children: rows.map((x) {
          final r = Map<String, dynamic>.from(x);
          final status = r['status'];
          return Card(
            child: ListTile(
              title: Text(r['donationTitle'] ?? 'Donation'),
              subtitle: Text(
                '${r['recipientName'] ?? r['donorName']} · ${pretty(status)}',
              ),
              trailing: status == 'PENDING' && widget.incoming
                  ? Wrap(
                      children: [
                        IconButton(
                          onPressed: () => decide(r['id'], 'REJECTED'),
                          icon: const Icon(Icons.close),
                        ),
                        IconButton(
                          onPressed: () => decide(r['id'], 'ACCEPTED'),
                          icon: const Icon(Icons.check),
                        ),
                      ],
                    )
                  : status == 'ACCEPTED' || status == 'COMPLETED'
                  ? Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Chat',
                          onPressed: () => openChat(context, r['id']),
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                        if (widget.incoming && status == 'ACCEPTED')
                          IconButton(
                            tooltip: 'Mark picked up',
                            onPressed: () => complete(r['id']),
                            icon: const Icon(Icons.done_all),
                          ),
                        if (!widget.incoming &&
                            status == 'COMPLETED' &&
                            !ratedRequests.contains(r['id']))
                          IconButton(
                            tooltip: 'Rate donor',
                            onPressed: () => rate(context, r['id']),
                            icon: const Icon(Icons.star_outline),
                          ),
                      ],
                    )
                  : null,
            ),
          );
        }).toList(),
      );
    },
  );
  Future<void> decide(dynamic id, String status) async {
    await Api.instance.dio.patch(
      '/requests/$id/decision',
      data: {'status': status},
    );
    await refresh();
  }

  Future<void> complete(dynamic id) async {
    await Api.instance.dio.patch('/requests/$id/complete');
    await refresh();
  }

  Future<void> openChat(BuildContext context, dynamic requestId) async {
    try {
      final response = await Api.instance.dio.post(
        '/requests/$requestId/conversation',
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversation: Map<String, dynamic>.from(response.data),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ?? 'Chat is unavailable.',
        );
      }
    }
  }

  Future<void> rate(BuildContext context, dynamic requestId) async {
    var score = 5;
    final review = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Rate your pickup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: score,
                items: List.generate(5, (i) => 5 - i)
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n stars')),
                    )
                    .toList(),
                onChanged: (v) => update(() => score = v ?? score),
              ),
              TextField(
                controller: review,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Optional review'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    try {
      await Api.instance.dio.post(
        '/requests/$requestId/rating',
        data: {'score': score, 'review': review.text},
      );
      if (mounted) setState(() => ratedRequests.add(requestId));
      if (context.mounted) snack(context, 'Thank you for your rating.');
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not submit your rating.',
        );
      }
    }
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = Api.instance.dio.get('/favorites').then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) => s.hasError
        ? ErrorPane(
            onRetry: () => setState(
              () => future = Api.instance.dio
                  .get('/favorites')
                  .then((r) => r.data),
            ),
          )
        : !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: (s.data as List)
                .map((x) => DonationCard(item: Map<String, dynamic>.from(x)))
                .toList(),
          ),
  );
}

class RecsPage extends StatefulWidget {
  const RecsPage({super.key});
  @override
  State<RecsPage> createState() => _RecsPageState();
}

class _RecsPageState extends State<RecsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = Api.instance.dio.get('/recommendations').then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) => s.hasError
        ? ErrorPane(
            onRetry: () => setState(
              () => future = Api.instance.dio
                  .get('/recommendations')
                  .then((r) => r.data),
            ),
          )
        : !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: (s.data as List)
                .map((x) => DonationCard(item: Map<String, dynamic>.from(x)))
                .toList(),
          ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      CircleAvatar(
        radius: 42,
        child: Text((user['name'] ?? '?')[0].toString().toUpperCase()),
      ),
      Text(
        user['name'] ?? '',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(user['email'] ?? '', textAlign: TextAlign.center),
      Text(
        '${user['role']} · ${user['city'] ?? 'City not set'}',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = Api.instance.dio.get('/admin/stats').then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(
          onRetry: () => setState(
            () => future = Api.instance.dio
                .get('/admin/stats')
                .then((r) => r.data),
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final x = s.data as Map;
      final keys = [
        'totalUsers',
        'donors',
        'recipients',
        'totalDonations',
        'availableDonations',
        'completedDonations',
        'pendingRequests',
        'openReports',
      ];
      return GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        children: keys
            .map(
              (k) => Card(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${x[k]}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(pretty(k)),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/users')).data['items'];
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        children: (s.data as List)
            .map(
              (u) => ListTile(
                title: Text(u['name']),
                subtitle: Text('${u['email']} · ${u['role']} · ${u['status']}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    await Api.instance.dio.patch(
                      '/admin/users/${u['id']}/status',
                      data: {'status': v},
                    );
                    setState(() => future = load());
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ACTIVE', child: Text('Activate')),
                    PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend')),
                    PopupMenuItem(value: 'BANNED', child: Text('Ban')),
                  ],
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class AdminDonationsPage extends StatefulWidget {
  const AdminDonationsPage({super.key});
  @override
  State<AdminDonationsPage> createState() => _AdminDonationsPageState();
}

class _AdminDonationsPageState extends State<AdminDonationsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/donations')).data;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = snapshot.data as List;
      if (items.isEmpty) {
        return const EmptyPane(
          title: 'No donations',
          subtitle: 'No listings need review.',
        );
      }
      return ListView(
        children: items.map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return ListTile(
            title: Text(item['title']?.toString() ?? 'Donation'),
            subtitle: Text(
              '${item['donorName']} · ${item['city']} · ${pretty(item['status'])}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'remove') {
                  await Api.instance.dio.delete(
                    '/admin/donations/${item['id']}',
                  );
                }
                if (mounted) setState(() => future = load());
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove listing')),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/reports')).data;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final reports = snapshot.data as List;
      if (reports.isEmpty) {
        return const EmptyPane(
          title: 'No reports',
          subtitle: 'New community reports will appear here.',
        );
      }
      return ListView(
        children: reports.map((raw) {
          final report = Map<String, dynamic>.from(raw);
          return Card(
            child: ListTile(
              title: Text(report['reason']?.toString() ?? 'Report'),
              subtitle: Text(
                '${report['reporterName']} · ${report['reportedUserName'] ?? report['donationTitle'] ?? ''}\n${report['details'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                tooltip: 'Set report status',
                onSelected: (status) async {
                  await Api.instance.dio.patch(
                    '/admin/reports/${report['id']}',
                    queryParameters: {'status': status},
                  );
                  if (mounted) setState(() => future = load());
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'REVIEWED',
                    child: Text('Mark reviewed'),
                  ),
                  PopupMenuItem(value: 'RESOLVED', child: Text('Resolve')),
                  PopupMenuItem(value: 'DISMISSED', child: Text('Dismiss')),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/notifications')).data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPane(onRetry: () => setState(() => future = load()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data as List;
        if (rows.isEmpty) {
          return const EmptyPane(
            title: 'All caught up',
            subtitle: 'Your notifications will show here.',
          );
        }
        return ListView(
          children: rows.map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return ListTile(
              leading: Icon(
                row['read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
              ),
              title: Text(row['title']?.toString() ?? 'Update'),
              subtitle: Text(row['body']?.toString() ?? ''),
              onTap: row['read'] == true
                  ? null
                  : () async {
                      await Api.instance.dio.patch(
                        '/notifications/${row['id']}/read',
                      );
                      if (mounted) setState(() => future = load());
                    },
            );
          }).toList(),
        );
      },
    ),
  );
}

class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});
  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  final input = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool busy = false;
  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || busy) return;
    input.clear();
    setState(() {
      messages.add({'text': question, 'who': 'You'});
      busy = true;
    });
    try {
      final response = await Api.instance.dio.post(
        '/chatbot',
        data: {'message': question},
      );
      if (mounted) {
        setState(
          () => messages.add({
            'text': response.data['answer']?.toString() ?? 'Please try again.',
            'who': 'ShareKind help',
          }),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => messages.add({
            'text':
                e.response?.data?['message']?.toString() ??
                'The help service could not respond.',
            'who': 'ShareKind help',
          }),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ShareKind help'),
    content: SizedBox(
      width: 420,
      height: 420,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: messages
                  .map(
                    (m) => ListTile(
                      title: Text(m['who']!),
                      subtitle: Text(m['text']!),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextField(
            controller: input,
            onSubmitted: (_) => send(),
            decoration: InputDecoration(
              hintText: 'Ask how the platform works',
              suffixIcon: IconButton(
                onPressed: busy ? null : send,
                icon: const Icon(Icons.send),
              ),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 48),
        const Text('Could not load data. Check the API connection.'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.volunteer_activism, size: 52, color: Colors.grey),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(subtitle),
      ],
    ),
  );
}

String pretty(String s) => s
    .toLowerCase()
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
