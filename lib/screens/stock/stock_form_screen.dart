import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../database/db_helper.dart';
import '../../models/perruque.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/photo_image.dart';
import '../../utils/photo_store.dart';

class StockFormScreen extends StatefulWidget {
  final Perruque? perruque;

  const StockFormScreen({super.key, this.perruque});

  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _type;
  late final TextEditingController _longueur;
  late final TextEditingController _couleur;
  late final TextEditingController _texture;
  late final TextEditingController _quantite;
  late final TextEditingController _prixAchat;
  late final TextEditingController _prixVente;
  String? _photoPath;
  bool _enregistrement = false;

  bool get _modification => widget.perruque != null;

  @override
  void initState() {
    super.initState();
    final p = widget.perruque;
    _nom = TextEditingController(text: p?.nom ?? '');
    _type = TextEditingController(text: p?.type ?? '');
    _longueur = TextEditingController(text: p?.longueur ?? '');
    _couleur = TextEditingController(text: p?.couleur ?? '');
    _texture = TextEditingController(text: p?.texture ?? '');
    _quantite = TextEditingController(text: '${p?.quantite ?? 1}');
    _prixAchat = TextEditingController(
        text: p == null ? '' : _nombre(p.prixAchat));
    _prixVente = TextEditingController(
        text: p == null ? '' : _nombre(p.prixVente));
    _photoPath = p?.photoPath;
  }

  @override
  void dispose() {
    _nom.dispose();
    _type.dispose();
    _longueur.dispose();
    _couleur.dispose();
    _texture.dispose();
    _quantite.dispose();
    _prixAchat.dispose();
    _prixVente.dispose();
    super.dispose();
  }

  String _nombre(double valeur) {
    if (valeur == valeur.roundToDouble()) return '${valeur.round()}';
    return '$valeur';
  }

  double? _parseMontant(String? valeur) {
    if (valeur == null) return null;
    return double.tryParse(valeur.trim().replaceAll(',', '.'));
  }

  Future<void> _choisirPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      final chemin = await savePickedPhoto(picked);
      if (!mounted) return;
      setState(() => _photoPath = chemin);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger la photo.')),
      );
    }
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enregistrement = true);

    final db = await DbHelper.instance.db;
    final nouvelle = Perruque(
      id: widget.perruque?.id,
      nom: _nom.text.trim(),
      type: _type.text.trim(),
      longueur: _longueur.text.trim(),
      couleur: _couleur.text.trim(),
      texture: _texture.text.trim(),
      quantite: int.parse(_quantite.text.trim()),
      prixAchat: _parseMontant(_prixAchat.text)!,
      prixVente: _parseMontant(_prixVente.text)!,
      photoPath: _photoPath,
    );

    if (!_modification) {
      final map = nouvelle.toMap();
      map['quantite'] = 0;
      final id = await db.insert('perruques', map);
      if (nouvelle.quantite > 0) {
        await StockService.instance.entreeStock(
          perruqueId: id,
          quantite: nouvelle.quantite,
          motif: 'Stock initial',
        );
      }
    } else {
      final ancienne = widget.perruque!;
      final delta = nouvelle.quantite - ancienne.quantite;
      await db.update(
        'perruques',
        nouvelle.toMap()..['quantite'] = ancienne.quantite,
        where: 'id = ?',
        whereArgs: [ancienne.id],
      );
      if (delta != 0) {
        await StockService.instance.changerQuantite(
          perruqueId: ancienne.id!,
          delta: delta,
          type: 'ajustement',
          motif: 'Modification fiche article',
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modification ? 'Modifier l\'article' : 'Nouvel article'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _blocPhoto(),
            const SizedBox(height: 20),
            _section('Informations générales', [
              _champ(
                _nom,
                'Nom de la perruque',
                icone: Icons.badge_outlined,
                majuscule: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le nom est requis'
                    : null,
              ),
              _champ(
                _type,
                'Type (Brésilien, Mongole...)',
                icone: Icons.category_outlined,
                majuscule: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le type est requis'
                    : null,
              ),
              _champ(
                _longueur,
                'Longueur (ex : 22")',
                icone: Icons.straighten,
              ),
              _champ(
                _couleur,
                'Couleur',
                icone: Icons.palette_outlined,
                majuscule: TextCapitalization.words,
              ),
              _champ(
                _texture,
                'Texture (lisse, ondulée...)',
                icone: Icons.texture,
                majuscule: TextCapitalization.words,
              ),
            ]),
            const SizedBox(height: 16),
            _section('Stock et prix', [
              _champ(
                _quantite,
                'Quantité en stock',
                icone: Icons.numbers,
                clavier: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Quantité invalide';
                  return null;
                },
              ),
              _champ(
                _prixAchat,
                'Prix d\'achat (FCFA)',
                icone: Icons.shopping_bag_outlined,
                clavier:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _parseMontant(v);
                  if (n == null || n < 0) return 'Prix d\'achat invalide';
                  return null;
                },
              ),
              _champ(
                _prixVente,
                'Prix de vente (FCFA)',
                icone: Icons.sell_outlined,
                clavier:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _parseMontant(v);
                  if (n == null || n <= 0) return 'Prix de vente invalide';
                  final achat = _parseMontant(_prixAchat.text);
                  if (achat != null && n < achat) {
                    return 'Le prix de vente est inférieur au prix d\'achat';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les changements de quantité sont enregistrés dans '
                    'l\'historique du stock.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _enregistrement ? null : _enregistrer,
            icon: _enregistrement
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_modification ? 'Enregistrer' : 'Ajouter au stock'),
          ),
        ),
      ),
    );
  }

  Widget _blocPhoto() {
    final provider = photoImageProvider(_photoPath);

    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: _choisirPhoto,
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.line),
                    image: provider != null
                        ? DecorationImage(
                            image: provider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: provider != null
                      ? null
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: AppColors.rose,
                        ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cream, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            provider != null
                ? 'Changer la photo'
                : 'Ajouter une photo (optionnel)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          if (provider != null)
            TextButton(
              onPressed: () => setState(() => _photoPath = null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retirer la photo'),
            ),
        ],
      ),
    );
  }

  Widget _section(String titre, List<Widget> champs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < champs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            champs[i],
          ],
        ],
      ),
    );
  }

  Widget _champ(
    TextEditingController controller,
    String label, {
    IconData? icone,
    TextInputType? clavier,
    TextCapitalization majuscule = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: clavier,
      textCapitalization: majuscule,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icone == null ? null : Icon(icone, size: 20),
      ),
    );
  }
}
