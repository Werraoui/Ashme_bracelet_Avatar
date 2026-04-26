from app.db.database import SessionLocal
from app.db.models import User

def test_connection():
    try:
        db = SessionLocal()

        # Simple query to test DB connection
        users = db.query(User).all()

        print("✅ Connection successful!")
        print(f"Users found: {len(users)}")

        for u in users:
            print(u.id_user, u.email)

    except Exception as e:
        print("❌ Connection failed!")
        print(e)

    finally:
        db.close()


if __name__ == "__main__":
    test_connection()