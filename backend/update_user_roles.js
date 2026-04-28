// Update existing user roles based on email patterns
const pool = require('./dbPool.js');

async function updateUserRoles() {
  try {
    console.log('Updating user roles...');
    
    // Get all users
    const usersResult = await pool.query('SELECT id, email, role FROM users');
    
    for (const user of usersResult.rows) {
      let newRole = 'teamMember'; // default
      
      // Determine role based on email patterns
      if (user.email.includes('admin') || user.email.includes('system')) {
        newRole = 'systemAdmin';
      } else if (user.email.includes('lead') || user.email.includes('manager') || user.email.includes('delivery')) {
        newRole = 'deliveryLead';
      } else if (user.email.includes('client') || user.email.includes('customer')) {
        newRole = 'clientUser';
      } else if (user.email.includes('approver') || user.email.includes('reviewer')) {
        newRole = 'internalApprover';
      } else if (user.email.includes('project') || user.email.includes('pm')) {
        newRole = 'projectManager';
      }
      
      // Update role if different
      if (user.role !== newRole) {
        await pool.query(
          'UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2',
          [newRole, user.id]
        );
        console.log(`Updated ${user.email}: ${user.role} -> ${newRole}`);
      }
    }
    
    console.log('User roles updated successfully!');
    process.exit(0);
  } catch (error) {
    console.error('Error updating user roles:', error);
    process.exit(1);
  }
}

updateUserRoles();
