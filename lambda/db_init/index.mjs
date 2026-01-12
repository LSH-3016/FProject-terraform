import pg from 'pg';

export const handler = async (event) => {
  const { Client } = pg;
  
  const client = new Client({
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    port: parseInt(process.env.DB_PORT || '5432'),
    ssl: false
  });

  try {
    await client.connect();

    // Create ENUM types
    await client.query(`
      DO $$ BEGIN
        CREATE TYPE library_item_type AS ENUM ('image', 'audio', 'video', 'document', 'other');
      EXCEPTION WHEN duplicate_object THEN null;
      END $$;
    `);

    await client.query(`
      DO $$ BEGIN
        CREATE TYPE visibility_type AS ENUM ('public', 'private', 'friends');
      EXCEPTION WHEN duplicate_object THEN null;
      END $$;
    `);

    // Create users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        user_id VARCHAR(255) PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        nickname VARCHAR(100),
        status VARCHAR(50) DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        deleted_at TIMESTAMP
      );
    `);

    // Create user_profiles table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_profiles (
        profile_id SERIAL PRIMARY KEY,
        user_id VARCHAR(255) UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
        profile_image_url TEXT,
        bio TEXT,
        phone_number VARCHAR(20),
        additional_info JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Create history table
    await client.query(`
      CREATE TABLE IF NOT EXISTS history (
        id BIGSERIAL PRIMARY KEY,
        user_id VARCHAR(255) NOT NULL,
        content TEXT,
        record_date DATE DEFAULT CURRENT_DATE,
        tags TEXT[],
        s3_key TEXT,
        text_url TEXT
      );
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_history_user_id ON history(user_id);`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_history_s3_key ON history(s3_key);`);

    // Create library_items table
    await client.query(`
      CREATE TABLE IF NOT EXISTS library_items (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type library_item_type NOT NULL,
        mime_type VARCHAR(100),
        visibility visibility_type DEFAULT 'private',
        s3_key VARCHAR(500),
        file_size BIGINT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_library_items_user_id ON library_items(user_id);`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_library_items_s3_key ON library_items(s3_key);`);

    // Create messages table
    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id VARCHAR(255) NOT NULL,
        content TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages(user_id);`);

    // Create trigger function
    await client.query(`
      CREATE OR REPLACE FUNCTION update_history_s3_key_on_library_delete()
      RETURNS TRIGGER AS $$
      BEGIN
        IF OLD.s3_key IS NOT NULL THEN
          UPDATE history SET s3_key = NULL WHERE s3_key = OLD.s3_key;
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    `);

    // Create trigger
    await client.query(`DROP TRIGGER IF EXISTS trigger_update_history_on_library_delete ON library_items;`);
    await client.query(`
      CREATE TRIGGER trigger_update_history_on_library_delete
      AFTER DELETE ON library_items
      FOR EACH ROW EXECUTE FUNCTION update_history_s3_key_on_library_delete();
    `);

    // Create updated_at function
    await client.query(`
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    // Apply updated_at triggers
    await client.query(`DROP TRIGGER IF EXISTS update_users_updated_at ON users;`);
    await client.query(`
      CREATE TRIGGER update_users_updated_at
      BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    `);

    await client.query(`DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;`);
    await client.query(`
      CREATE TRIGGER update_user_profiles_updated_at
      BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    `);

    return { statusCode: 200, body: JSON.stringify({ message: 'Database tables created successfully' }) };

  } catch (error) {
    console.error('Error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  } finally {
    await client.end();
  }
};
