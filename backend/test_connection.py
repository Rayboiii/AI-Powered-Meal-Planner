import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

load_dotenv()

print("=== Testing MySQL Connection ===")
print(f"Host: {os.getenv('DATABASE_HOST')}")
print(f"Port: {os.getenv('DATABASE_PORT')}")
print(f"User: {os.getenv('DATABASE_USER')}")
print(f"Password length: {len(os.getenv('DATABASE_PASSWORD', ''))}")
print(f"Database: {os.getenv('DATABASE_NAME')}")
print()

# Test 1: Try connecting with localhost
print("Test 1: Connecting with localhost...")
try:
    connection = mysql.connector.connect(
        host='localhost',
        port=int(os.getenv('DATABASE_PORT', 3307)),
        user=os.getenv('DATABASE_USER'),
        password=os.getenv('DATABASE_PASSWORD'),
        database=os.getenv('DATABASE_NAME')
    )
    
    if connection.is_connected():
        print("✅ Connected with localhost!")
        connection.close()
except Error as e:
    print(f"❌ Failed with localhost: {e}")

print()

# Test 2: Try connecting with 127.0.0.1
print("Test 2: Connecting with 127.0.0.1...")
try:
    connection = mysql.connector.connect(
        host='127.0.0.1',
        port=int(os.getenv('DATABASE_PORT', 3307)),
        user=os.getenv('DATABASE_USER'),
        password=os.getenv('DATABASE_PASSWORD'),
        database=os.getenv('DATABASE_NAME')
    )
    
    if connection.is_connected():
        print("✅ Connected with 127.0.0.1!")
        
        cursor = connection.cursor()
        cursor.execute("SELECT DATABASE();")
        db = cursor.fetchone()
        print(f"✅ Database: {db[0]}")
        
        cursor.execute("SHOW TABLES;")
        tables = cursor.fetchall()
        print(f"✅ Tables: {len(tables)}")
        for table in tables:
            print(f"   - {table[0]}")
        
        cursor.close()
        connection.close()
        
except Error as e:
    print(f"❌ Failed with 127.0.0.1: {e}")

print()

# Test 3: Try without specifying database
print("Test 3: Connecting without database specified...")
try:
    connection = mysql.connector.connect(
        host='127.0.0.1',
        port=int(os.getenv('DATABASE_PORT', 3307)),
        user=os.getenv('DATABASE_USER'),
        password=os.getenv('DATABASE_PASSWORD')
    )
    
    if connection.is_connected():
        print("✅ Connected without database!")
        
        cursor = connection.cursor()
        cursor.execute("SHOW DATABASES;")
        databases = cursor.fetchall()
        print("Available databases:")
        for db in databases:
            print(f"   - {db[0]}")
        
        cursor.close()
        connection.close()
        
except Error as e:
    print(f"❌ Failed: {e}")