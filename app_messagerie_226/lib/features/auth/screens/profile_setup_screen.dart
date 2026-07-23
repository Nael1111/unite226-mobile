import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/auth_controller.dart';
import '../../../core/theme.dart';
import '../../../core/services/cloudinary_service.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _cnibFront;
  File? _cnibBack;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir depuis le compte Google
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user?.displayName != null) {
      final parts = user!.displayName!.split(' ');
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) _lastNameCtrl.text = parts.skip(1).join(' ');
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      if (isFront) _cnibFront = File(picked.path);
      else _cnibBack = File(picked.path);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cnibFront == null || _cnibBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les deux faces du CNIB sont obligatoires'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser!;
      final cloudinary = ref.read(cloudinaryServiceProvider);

      final cnibFrontUrl = await cloudinary.uploadIdCard(_cnibFront!, user.uid, 'front');
      final cnibBackUrl = await cloudinary.uploadIdCard(_cnibBack!, user.uid, 'back');

      await ref.read(firestoreProvider).collection('users').doc(user.uid).set({
        'email': user.email,
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'displayName': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        'profilePhotoUrl': user.photoURL ?? '',
        'cnibFrontUrl': cnibFrontUrl,
        'cnibBackUrl': cnibBackUrl,
        'role': 'user',
        'accountStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter votre profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informations personnelles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'Prénom *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Prénom requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 32),
                Text('CNIB (Carte Nationale d\'Identité Burkinabè) *',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Recto et verso obligatoires pour validation',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _CnibPicker(label: 'Recto', file: _cnibFront, onTap: () => _pickImage(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _CnibPicker(label: 'Verso', file: _cnibBack, onTap: () => _pickImage(false))),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre compte sera activé après vérification de votre identité par un administrateur.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Soumettre mon dossier'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CnibPicker extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _CnibPicker({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: file != null ? AppTheme.primary : Colors.grey),
          borderRadius: BorderRadius.circular(12),
          image: file != null ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover) : null,
        ),
        child: file == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ])
            : null,
      ),
    );
  }
}
