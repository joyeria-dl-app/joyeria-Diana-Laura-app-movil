import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/legal_service.dart';
import '../theme/app_theme.dart';

// Hoja que sube desde abajo con los términos o el aviso de privacidad (#321). Se abre desde el
// registro sin perder lo escrito, y desde Mi perfil o el inicio de sesión para consultarlos.
Future<void> mostrarDocumentoLegal(BuildContext context, DocumentoLegal doc) {
  final servicio = context.read<LegalService>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => _Contenido(doc: doc, servicio: servicio, scroll: scroll),
    ),
  );
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.doc, required this.servicio, required this.scroll});

  final DocumentoLegal doc;
  final LegalService servicio;
  final ScrollController scroll;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  late Future<TextoLegal> _texto = widget.servicio.obtener(widget.doc);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.doc.nombre,
                  style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('legal_cerrar'),
                tooltip: 'Cerrar',
                icon: Icon(Icons.close_rounded, color: AppColors.textoSuave),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borde),
        Expanded(
          child: FutureBuilder<TextoLegal>(
            future: _texto,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(child: CircularProgressIndicator(color: AppColors.primario));
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snap.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                        const SizedBox(height: 12),
                        TextButton(onPressed: () => setState(() => _texto = widget.servicio.obtener(widget.doc)), child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                children: [SelectableText(snap.data!.contenido, style: TextStyle(color: AppColors.texto, fontSize: 13.5, height: 1.55))],
              );
            },
          ),
        ),
      ],
    );
  }
}
