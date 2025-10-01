# Changelog

All notable changes to the DHCP REST Agent project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-30

### Added
- Complete REST API for Windows DHCP Server reservation management
- Full CRUD operations (GET, POST, PUT, DELETE) for DHCP reservations
- PowerShell module `DHCPReservationManager` with 5 public functions
- Bearer token and mTLS authentication support
- Comprehensive audit logging (file + Windows Event Log)
- Rate limiting with configurable thresholds
- Input validation and XSS protection
- Health check endpoint with system diagnostics
- Windows Service deployment scripts
- TLS/HTTPS support with certificate generation script
- Hierarchical JSON configuration with local overrides
- Comprehensive documentation (README, QUICKSTART, TROUBLESHOOTING)
- Migration script for importing switch DHCP reservations

### Fixed
- **PowerShell parameter escaping bug** - IP addresses and simple values were incorrectly wrapped in single quotes, causing validation failures
  - Changed parameter building to only quote values containing spaces or special characters
  - Affects: `src/services/powershell.js` lines 30-42 and 157-168

- **Config deep merge bug** - Nested configuration properties in `config/local.json` weren't properly overriding `config/default.json` values
  - Rewrote `deepMerge` function to correctly handle nested object merging
  - Affects: `src/utils/config.js` lines 22-38

- **Delete idempotency bug** - DELETE operations returned 409 Conflict when reservation didn't exist instead of treating as successful idempotent operation
  - Added "Failed to get reservation" to the list of errors treated as successful deletes
  - Affects: `modules/DHCPReservationManager/Public/Remove-DHCPReservation.ps1` line 62

### Known Limitations
- Performance: Node.js spawning PowerShell processes is slower than .NET in-process (200-500ms latency)
- Concurrent requests limited to 10 simultaneous by default (configurable)
- Some PowerShell error messages could be more descriptive
- Unit tests not fully implemented (framework in place)
- RBAC authorization is placeholder only

### Security
- Disabled authentication and TLS by default in development via `config/local.json`
- Added rate limiting (100 req/min global, 50 req/min for write operations)
- XSS protection via HTML tag stripping in input validation
- Helmet.js security headers (CSP, HSTS, XSS protection)
- Request size limits (100kb JSON, 50kb URL-encoded)

### Documentation
- [README.md](README.md) - Complete user documentation
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Comprehensive troubleshooting guide
- [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md) - Project overview and architecture
- [CLAUDE.md](CLAUDE.md) - AI development guidance
- [CHANGELOG.md](CHANGELOG.md) - This file

### Infrastructure
- Git repository initialized with proper .gitignore
- GitHub repository: https://github.com/jpearcy02/DHCP-Control
- Environment-specific files excluded from version control
- Node.js 18+ with Express.js 4.21
- PowerShell 5.1+ integration

## [Unreleased]

### Planned Enhancements
- Migrate to .NET Core with in-process PowerShell for 10-100x performance improvement
- Implement comprehensive unit and integration test suite
- Add Prometheus metrics endpoint
- Build web UI dashboard (React/Vue)
- Support bulk operations (CSV import/export)
- Extend to manage DHCP scopes, leases, and server options
- Add centralized controller for multi-server management
- Implement full RBAC with role-based permissions
- Add centralized logging integration (Splunk/ELK)
- Create CI/CD pipeline (GitHub Actions)

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2025-09-30 | Initial release with full CRUD operations and bug fixes |

## Upgrade Notes

### Upgrading from Pre-1.0.0

If you were using an earlier development version:

1. **Update PowerShell service:**
   ```powershell
   # Copy updated file
   copy src\services\powershell.js c:\DHCP Control\src\services\powershell.js
   ```

2. **Update config utility:**
   ```powershell
   copy src\utils\config.js c:\DHCP Control\src\utils\config.js
   ```

3. **Update Remove-DHCPReservation script:**
   ```powershell
   copy modules\DHCPReservationManager\Public\Remove-DHCPReservation.ps1 c:\DHCP Control\modules\DHCPReservationManager\Public\Remove-DHCPReservation.ps1
   ```

4. **Restart the service:**
   ```powershell
   # Development
   # Type 'rs' in nodemon console

   # Production
   Restart-Service DHCPRestAgent
   ```

## Contributors

- Claude (AI Assistant) - Initial development and bug fixes
- jpearcy02 - Project owner and testing

## License

See [LICENSE](LICENSE) file for details.
