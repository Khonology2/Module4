// This script updates the signup endpoint to preserve user roles
const fs = require('fs');

// Read the current server.js file
let serverContent = fs.readFileSync('./server.js', 'utf8');

// Find and replace the signup endpoint user creation logic
const oldSignupLogic = `    // Create new user
    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = uuidv4();

    const result = await pool.query(
      'INSERT INTO users (id, email, password_hash, first_name, last_name, role, created_at, updated_at, is_active) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), true) RETURNING id, email, first_name, last_name, role, created_at, is_active',
      [userId, email, hashedPassword, firstName, lastName, role]
    );`;

const newSignupLogic = `    // Create new user with proper role assignment
    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = uuidv4();

    // Ensure role is properly set, fallback to teamMember if invalid
    const validRoles = ['systemAdmin', 'deliveryLead', 'teamMember', 'clientUser', 'internalApprover'];
    const userRole = validRoles.contains(role) ? role : 'teamMember';

    const result = await pool.query(
      'INSERT INTO users (id, email, password_hash, first_name, last_name, role, created_at, updated_at, is_active) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), true) RETURNING id, email, first_name, last_name, role, created_at, is_active',
      [userId, email, hashedPassword, firstName, lastName, userRole]
    );`;

// Replace the old logic with new logic
if (serverContent.includes(oldSignupLogic)) {
    const updatedContent = serverContent.replace(oldSignupLogic, newSignupLogic);
    
    // Also update the success message
    const updatedContent2 = updatedContent.replace(
        'console.log(`✅ User created successfully: ${email}`);',
        'console.log(`✅ User created successfully: ${email} with role: ${userRole}`);'
    );
    
    fs.writeFileSync('./server.js', updatedContent2);
    console.log('✅ Signup endpoint updated to preserve user roles');
} else {
    console.log('❌ Could not find signup logic to update');
}
