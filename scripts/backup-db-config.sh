#!/bin/bash

# Database Configuration Backup Script
# This script backs up your critical database configuration files

BACKUP_DIR="backups/db-config"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="db_config_backup_$TIMESTAMP"

echo "Creating database configuration backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Copy critical configuration files
cp backend/.env "$BACKUP_DIR/$BACKUP_NAME.env" 2>/dev/null || echo "Warning: backend/.env not found"
cp backend/node-backend/.env.sit "$BACKUP_DIR/$BACKUP_NAME.sit.env" 2>/dev/null || echo "Warning: .env.sit not found"
cp backend/dbPool.js "$BACKUP_DIR/$BACKUP_NAME.dbPool.js" 2>/dev/null || echo "Warning: dbPool.js not found"

# Create a restore script
cat > "$BACKUP_DIR/restore_$BACKUP_NAME.sh" << EOF
#!/bin/bash

echo "Restoring database configuration from backup..."

# Restore environment files
cp "$BACKUP_DIR/$BACKUP_NAME.env" backend/.env 2>/dev/null || echo "Warning: Could not restore backend/.env"
cp "$BACKUP_DIR/$BACKUP_NAME.sit.env" backend/node-backend/.env.sit 2>/dev/null || echo "Warning: Could not restore .env.sit"
cp "$BACKUP_DIR/$BACKUP_NAME.dbPool.js" backend/dbPool.js 2>/dev/null || echo "Warning: Could not restore dbPool.js"

echo "Database configuration restore completed!"
echo "Please restart your backend services."
EOF

chmod +x "$BACKUP_DIR/restore_$BACKUP_NAME.sh"

echo "Backup completed: $BACKUP_DIR/"
echo "To restore, run: $BACKUP_DIR/restore_$BACKUP_NAME.sh"
