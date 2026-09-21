import 'package:flutter/material.dart';

import '../core/models/concentrator_account.dart';
import '../core/models/session.dart';
import '../core/utils/currency_format.dart';
import '../features/balance_operations/aprobaciones_section.dart';
import '../features/balance_operations/balance_operation_repository.dart';
import '../features/cardholders/cardholder_repository.dart';
import '../features/cardholders/tarjetahabientes_section.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/tarjetas_section.dart';
import '../features/clients/client_repository.dart';
import '../features/dashboard/dashboard_repository.dart';
import '../features/dashboard/dashboard_section.dart';
import '../features/ledger/ledger_repository.dart';
import '../features/clients/clientes_section.dart';
import '../features/staff_users/staff_user_repository.dart';
import '../features/treasury/treasury_repository.dart';
import 'auth_controller.dart';
import 'theme.dart';

enum _Section { inicio, clientes, tarjetahabientes, tarjetas, aprobaciones }

extension on _Section {
  String get label {
    switch (this) {
      case _Section.inicio:
        return 'Inicio';
      case _Section.clientes:
        return 'Clientes';
      case _Section.tarjetahabientes:
        return 'Tarjetahabientes';
      case _Section.tarjetas:
        return 'Tarjetas';
      // Hub de pendientes de aprobación + depósitos por conciliar +
      // historial completo — ver AprobacionesSection. Absorbió la
      // antigua sección "Operaciones de saldo" el 2026-09-17 (dos ítems
      // de menú sobre lo mismo no aportaba).
      case _Section.aprobaciones:
        return 'Operaciones de saldo';
    }
  }

  IconData get icon {
    switch (this) {
      case _Section.inicio:
        return Icons.dashboard_rounded;
      case _Section.clientes:
        return Icons.corporate_fare_rounded;
      case _Section.tarjetahabientes:
        return Icons.people_alt_rounded;
      case _Section.tarjetas:
        return Icons.credit_card_rounded;
      case _Section.aprobaciones:
        return Icons.swap_horiz_rounded;
    }
  }

}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
    required this.treasuryRepository,
    required this.dashboardRepository,
    required this.staffUserRepository,
    required this.authController,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;
  final TreasuryRepository treasuryRepository;
  final DashboardRepository dashboardRepository;
  final StaffUserRepository staffUserRepository;
  final AuthController authController;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late _Section _selected;

  /// 0 = Operaciones de saldo, 1 = Depósitos por conciliar — solo lo
  /// mueve el hipervínculo de "Requiere tu atención" en Inicio; entrar a
  /// "Aprobaciones" desde el sidebar siempre reinicia a 0. Ver
  /// AprobacionesSection.initialTabIndex.
  int _aprobacionesTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Solo los roles con Panel directivo aterrizan en "Inicio" — Operador
    // y Auditor siguen aterrizando en "Clientes". Ver
    // docs/feature/panel-directivo/README.md.
    _selected = widget.session.role.canViewExecutiveDashboard ? _Section.inicio : _Section.clientes;
  }

  String get _initials {
    final email = widget.session.email;
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            session: widget.session,
            selected: _selected,
            onSelect: (section) => setState(() {
              _selected = section;
              // Entrar por el sidebar siempre abre la primera pestaña —
              // solo el link desde Inicio decide abrir la de depósitos.
              if (section == _Section.aprobaciones) _aprobacionesTabIndex = 0;
            }),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _selected.label,
                  session: widget.session,
                  initials: _initials,
                  treasuryRepository: widget.treasuryRepository,
                  onLogout: widget.authController.logout,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selected) {
      case _Section.inicio:
        return DashboardSection(
          session: widget.session,
          dashboardRepository: widget.dashboardRepository,
          onNavigateToAprobaciones: (tabIndex) => setState(() {
            _selected = _Section.aprobaciones;
            _aprobacionesTabIndex = tabIndex;
          }),
        );
      case _Section.clientes:
        return ClientesSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
          cardRepository: widget.cardRepository,
          ledgerRepository: widget.ledgerRepository,
          balanceOperationRepository: widget.balanceOperationRepository,
          treasuryRepository: widget.treasuryRepository,
          staffUserRepository: widget.staffUserRepository,
        );
      case _Section.tarjetahabientes:
        return TarjetahabientesSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
          cardRepository: widget.cardRepository,
          ledgerRepository: widget.ledgerRepository,
          balanceOperationRepository: widget.balanceOperationRepository,
        );
      case _Section.tarjetas:
        return TarjetasSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
          cardRepository: widget.cardRepository,
          ledgerRepository: widget.ledgerRepository,
          balanceOperationRepository: widget.balanceOperationRepository,
        );
      case _Section.aprobaciones:
        return AprobacionesSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
          cardRepository: widget.cardRepository,
          ledgerRepository: widget.ledgerRepository,
          balanceOperationRepository: widget.balanceOperationRepository,
          treasuryRepository: widget.treasuryRepository,
          initialTabIndex: _aprobacionesTabIndex,
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.session, required this.selected, required this.onSelect});

  final Session session;
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    // "Inicio" (Panel directivo) solo para quien puede verlo — ver
    // docs/feature/panel-directivo/README.md.
    final visibleSections = _Section.values
        .where((s) => s != _Section.inicio || session.role.canViewExecutiveDashboard)
        .toList();
    return Container(
      width: 248,
      color: KoonsColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/images/kbm_logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'KBM Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          for (final section in visibleSections)
            _SidebarItem(
              section: section,
              isSelected: section == selected,
              onTap: () => onSelect(section),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Koons Balance Management',
              style: TextStyle(color: KoonsColors.sidebarText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.section, required this.isSelected, required this.onTap});

  final _Section section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? KoonsColors.sidebarTextActive : KoonsColors.sidebarText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? KoonsColors.sidebarItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(section.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.session,
    required this.initials,
    required this.treasuryRepository,
    required this.onLogout,
  });

  final String title;
  final Session session;
  final String initials;
  final TreasuryRepository treasuryRepository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KoonsColors.border)),
      ),
      child: Row(
        children: [
          // Expanded (not Flexible+Spacer) so the title alone absorbs all
          // leftover space — a loose Flexible here competed with Spacer
          // for an even flex share, leaving unclaimed space stranded past
          // the logout icon instead of pinning the trailing block to the
          // true right edge. That leftover varied with the title's own
          // width, which is why the block visibly shifted per screen.
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: KoonsColors.navy),
            ),
          ),
          // Admin Cliente only — Super Admin has no empresa propia
          // (session.clientId is null) and no Concentradora belongs to
          // it directly yet. See docs/feature/tesoreria-cliente/README.md,
          // "Indicador de saldo en el encabezado".
          if (session.role.canManageCardholders && session.clientId != null) ...[
            _ConcentratorBalanceChip(clientId: session.clientId!, treasuryRepository: treasuryRepository),
            const SizedBox(width: 16),
          ],
          CircleAvatar(
            radius: 15,
            backgroundColor: KoonsColors.blue,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          // A plain ConstrainedBox, not Flexible — a second flex
          // participant here competed with the title's Expanded for the
          // same leftover space (same bug class as the earlier
          // Flexible+Spacer title issue). Since it's loose fit and this
          // text rarely needs its full share, the unclaimed remainder
          // ended up stranded past the logout icon instead of at the true
          // right edge. This only needs a sane max width for pathologically
          // long emails, not a share of the row's free space.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  session.role.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // IconButton's default 48x48 tap target adds a lot of invisible
          // padding around the icon — against the container's 24px inset,
          // that made the whole trailing block look like it stopped well
          // short of the true right edge instead of hugging it. Tightened
          // to match the visual rhythm of the rest of the bar.
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Saldo de la Concentradora de la propia empresa de un Admin Cliente —
/// puramente informativo (nunca un botón, no navega a Tesorería). Se
/// obtiene una sola vez al montar, no se refresca en vivo si se hace una
/// operación en otra pantalla durante la misma sesión — ver
/// docs/feature/tesoreria-cliente/README.md, "Indicador de saldo en el
/// encabezado".
class _ConcentratorBalanceChip extends StatefulWidget {
  const _ConcentratorBalanceChip({required this.clientId, required this.treasuryRepository});

  final String clientId;
  final TreasuryRepository treasuryRepository;

  @override
  State<_ConcentratorBalanceChip> createState() => _ConcentratorBalanceChipState();
}

class _ConcentratorBalanceChipState extends State<_ConcentratorBalanceChip> {
  late final Future<ConcentratorAccount?> _future = widget.treasuryRepository.getConcentratorAccount(widget.clientId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConcentratorAccount?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final account = snapshot.data!;
        return Tooltip(
          message: 'Saldo de la Cuenta Concentradora de tu empresa',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KoonsColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KoonsColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_rounded, size: 16, color: KoonsColors.blue),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(account.balance, account.currency),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KoonsColors.navy),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
