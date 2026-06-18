"""
Generate dummy CSV source data for the PT. LDR data warehouse project.

The script overwrites the 8 source CSV files in the data folder while keeping
the same headers expected by the existing staging and transform SQL scripts.
"""

from __future__ import annotations

import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data"

CITIES = [
    ("Jakarta", "DKI Jakarta", "Jabodetabek"),
    ("Jakarta Pusat", "DKI Jakarta", "Jabodetabek"),
    ("Bandung", "Jawa Barat", "West Java"),
    ("Bogor", "Jawa Barat", "Jabodetabek"),
    ("Tangerang", "Banten", "Jabodetabek"),
    ("Bekasi", "Jawa Barat", "Jabodetabek"),
    ("Surabaya", "Jawa Timur", "East Java"),
    ("Malang", "Jawa Timur", "East Java"),
    ("Semarang", "Jawa Tengah", "Central Java"),
    ("Yogyakarta", "DI Yogyakarta", "Central Java"),
    ("Solo", "Jawa Tengah", "Central Java"),
    ("Denpasar", "Bali", "Bali Nusra"),
    ("Medan", "Sumatera Utara", "Sumatra"),
    ("Palembang", "Sumatera Selatan", "Sumatra"),
    ("Padang", "Sumatera Barat", "Sumatra"),
    ("Pekanbaru", "Riau", "Sumatra"),
    ("Batam", "Kepulauan Riau", "Sumatra"),
    ("Makassar", "Sulawesi Selatan", "Sulawesi"),
    ("Manado", "Sulawesi Utara", "Sulawesi"),
    ("Balikpapan", "Kalimantan Timur", "Kalimantan"),
    ("Banjarmasin", "Kalimantan Selatan", "Kalimantan"),
    ("Pontianak", "Kalimantan Barat", "Kalimantan"),
    ("Mataram", "Nusa Tenggara Barat", "Bali Nusra"),
    ("Kupang", "Nusa Tenggara Timur", "Bali Nusra"),
]

FIRST_NAMES = [
    "Andi",
    "Budi",
    "Citra",
    "Dewi",
    "Eka",
    "Fajar",
    "Gita",
    "Hendra",
    "Indra",
    "Joko",
    "Kartika",
    "Lestari",
    "Maya",
    "Nadia",
    "Putra",
    "Rani",
    "Sari",
    "Tono",
    "Utami",
    "Wulan",
]

LAST_NAMES = [
    "Wijaya",
    "Santoso",
    "Pratama",
    "Saputra",
    "Wulandari",
    "Lestari",
    "Gunawan",
    "Hartono",
    "Putri",
    "Maulana",
]

SERVICES = [
    ("REG", "Regular Delivery", "Regular", "2-4 Days", "30", "Yes", "Active", 3),
    ("EXP", "Express Delivery", "Express", "1 Day", "10 kg", "YES", "Active", 1),
    ("ECO", "Economy Delivery", "Economy", "3-7 Days", "20", "No", "1", 5),
    ("CARGO", "Cargo Delivery", "Cargo", "3-8 Days", "100 KG", "N", "Active", 6),
    ("COD", "Cash On Delivery", "Regular", "2-5 Days", "15", "Available", "Aktif", 3),
    ("SDS", "Same Day Service", "Express", "Same Day", "5 kg", "YES", "Active", 0),
    ("TRK", "Trucking Service", "Cargo", "4-10 Days", "150", "No", "Active", 7),
]

STATUSES = [
    ("ONP", "On Process", "Process", "Package is being processed"),
    ("TRN", "In Transit", "Process", "Package is in transit"),
    ("OFD", "Out For Delivery", "Process", "Package is out for delivery"),
    ("DLV", "Delivered", "Success", "Package has been delivered"),
    ("FAIL", "Failed", "Failed", "Delivery failed"),
    ("RTR", "Returned", "Return", "Package returned to sender"),
    ("CANCEL", "Cancelled", "Cancelled", "Shipment was cancelled"),
]

PACKAGE_TYPES = [
    ("Document", "Small"),
    ("Parcel", "Medium"),
    ("Electronics", "Medium"),
    ("Food", "Small"),
    ("Cargo", "Cargo"),
    ("Fragile Goods", "Medium"),
    ("Clothing", "Small"),
    ("Spare Parts", "Large"),
]

PAYMENT_METHODS = [
    ("Cash", "Outlet", "Not Applicable", "Paid", "No", "Not Refunded"),
    ("Bank Transfer", "Mobile App", "BCA", "Paid", "No", "Not Refunded"),
    ("E-Wallet", "Mobile App", "OVO", "Paid", "No", "Not Refunded"),
    ("Virtual Account", "Website", "MANDIRI", "Paid", "No", "Not Refunded"),
    ("COD", "Outlet", "Not Applicable", "Pending", "Yes", "Not Refunded"),
    ("Corporate Billing", "Corporate System", "Not Applicable", "Paid", "No", "Not Refunded"),
]


def clean_slug(value: str) -> str:
    return value.lower().replace(" ", ".")


def date_text(value: date, variant: int) -> str:
    if variant == 0:
        return value.strftime("%Y-%m-%d")
    if variant == 1:
        return value.strftime("%d/%m/%Y")
    if variant == 2:
        return value.strftime("%Y/%m/%d")
    if variant == 3:
        return value.strftime("%d-%m-%Y")
    return value.strftime("%b %d %Y")


def money_text(value: int, variant: int) -> str:
    if variant == 0:
        return str(value)
    if variant == 1:
        return f"Rp {value}"
    if variant == 2:
        return f"Rp{value}"
    return f"{value:,}".replace(",", ".")


def person_name() -> str:
    return f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"


def phone_number(index: int) -> str:
    return f"0812{index:08d}"


def write_csv(path: Path, headers: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def generate_branches(count: int) -> list[dict[str, object]]:
    rows = []
    branch_types = ["Main Branch", "Outlet", "Warehouse", "Sorting Center"]
    streets = ["Jl. Merdeka", "Jl. Sudirman", "Jl. Thamrin", "Jl. Pemuda", "Jl. Diponegoro"]
    for index in range(1, count + 1):
        city, province, region = CITIES[(index - 1) % len(CITIES)]
        opened = date(2016, 1, 1) + timedelta(days=random.randint(0, 3000))
        rows.append(
            {
                "branch_id": f"BR{index:03d}",
                "branch_name": f"LDR {city}",
                "branch_type": random.choice(branch_types),
                "address": f"{random.choice(streets)} No. {random.randint(1, 120)}",
                "city": city,
                "province": province,
                "region": region,
                "manager_name": person_name(),
                "opening_date": date_text(opened, index % 5),
                "is_active": random.choice(["Yes", "Y", "Active", "1", "True"]),
            }
        )
    return rows


def generate_customers(count: int) -> list[dict[str, object]]:
    rows = []
    customer_types = ["Individual", "Corporate", "Marketplace Seller", "E-Commerce Partner"]
    genders = ["Male", "Female"]
    for index in range(1, count + 1):
        name = person_name()
        city, province, _region = random.choice(CITIES)
        registered = date(2020, 1, 1) + timedelta(days=random.randint(0, 2300))
        rows.append(
            {
                "customer_id": f"C{index:04d}",
                "customer_name": name,
                "customer_type": random.choice(customer_types),
                "gender": random.choice(genders),
                "phone": phone_number(index),
                "email": f"{clean_slug(name)}{index}@example.com",
                "city": city,
                "province": province,
                "registration_date": date_text(registered, index % 5),
                "status": random.choice(["Active", "Yes", "Y", "1", "True"]),
            }
        )
    return rows


def generate_couriers(count: int, branches: list[dict[str, object]]) -> list[dict[str, object]]:
    rows = []
    vehicle_types = ["Motorcycle", "Car", "Van", "Truck"]
    employee_statuses = ["Permanent", "Contract", "Outsourced"]
    for index in range(1, count + 1):
        hired = date(2018, 1, 1) + timedelta(days=random.randint(0, 2600))
        rows.append(
            {
                "courier_id": f"CR{index:04d}",
                "courier_name": person_name(),
                "gender": random.choice(["Male", "Female"]),
                "phone": phone_number(50000 + index),
                "branch_id": random.choice(branches)["branch_id"],
                "vehicle_type": random.choice(vehicle_types),
                "hire_date": date_text(hired, index % 5),
                "employee_status": random.choice(employee_statuses),
                "is_active": random.choice(["Active", "Yes", "Y", "1", "True"]),
            }
        )
    return rows


def generate_packages(count: int) -> list[dict[str, object]]:
    rows = []
    descriptions = [
        "Customer document",
        "Fashion item",
        "Electronic accessory",
        "Food product",
        "Vehicle spare part",
        "Household goods",
        "Office supplies",
    ]
    for index in range(1, count + 1):
        package_type, package_category = random.choice(PACKAGE_TYPES)
        if package_category == "Small":
            weight = round(random.uniform(0.1, 3.0), 2)
        elif package_category == "Medium":
            weight = round(random.uniform(3.1, 15.0), 2)
        elif package_category == "Large":
            weight = round(random.uniform(15.1, 40.0), 2)
        else:
            weight = round(random.uniform(40.1, 120.0), 2)
        rows.append(
            {
                "package_id": f"PKG{index:05d}",
                "package_type": package_type,
                "package_category": package_category,
                "weight": f"{weight} kg" if index % 7 == 0 else f"{weight}",
                "weight_unit": "KG",
                "length_cm": random.randint(10, 120),
                "width_cm": random.randint(8, 80),
                "height_cm": random.randint(3, 70),
                "fragile_flag": random.choice(["Yes", "No", "Y", "N", "1", "0"]),
                "insured_flag": random.choice(["Yes", "No", "Y", "N", "1", "0"]),
                "item_description": random.choice(descriptions),
            }
        )
    return rows


def generate_payments(count: int, start_date: date) -> list[dict[str, object]]:
    rows = []
    for index in range(1, count + 1):
        method, channel, bank, status, is_cod, refund = random.choice(PAYMENT_METHODS)
        paid_date = start_date + timedelta(days=random.randint(0, 540))
        rows.append(
            {
                "payment_id": f"PAY{index:05d}",
                "payment_method": method,
                "payment_channel": channel,
                "bank_name": bank,
                "payment_date": date_text(paid_date, index % 5),
                "payment_status": status,
                "is_cod": is_cod,
                "refund_status": refund,
            }
        )
    return rows


def generate_shipments(
    count: int,
    customers: list[dict[str, object]],
    branches: list[dict[str, object]],
    couriers: list[dict[str, object]],
    packages: list[dict[str, object]],
    payments: list[dict[str, object]],
    start_date: date,
) -> list[dict[str, object]]:
    rows = []
    service_by_code = {service[0]: service for service in SERVICES}
    status_choices = ["DLV"] * 70 + ["ONP"] * 8 + ["TRN"] * 7 + ["OFD"] * 5 + ["FAIL"] * 4 + ["RTR"] * 4 + ["CANCEL"] * 2
    for index in range(1, count + 1):
        service = random.choice(SERVICES)
        service_code = service[0]
        estimated_days = service_by_code[service_code][7]
        transaction_date = start_date + timedelta(days=random.randint(0, 540))
        pickup_date = transaction_date + timedelta(days=random.randint(0, 1))
        status_code = random.choice(status_choices)
        is_finished = status_code in {"DLV", "FAIL", "RTR", "CANCEL"}
        actual_days = None
        delivery_date = None
        if is_finished:
            actual_days = max(0, estimated_days + random.choice([-1, 0, 0, 1, 2, 3]))
            delivery_date = pickup_date + timedelta(days=actual_days)
        shipping_fee = random.randint(12000, 150000)
        insurance_fee = random.choice([0, 0, 0, random.randint(2000, 25000)])
        discount_amount = random.choice([0, 0, 0, 3000, 5000, 10000])
        total_amount = shipping_fee + insurance_fee - discount_amount
        rows.append(
            {
                "shipment_id": f"SHP{index:05d}",
                "awb_number": f"LDR{transaction_date:%y}{index:08d}",
                "transaction_date": date_text(transaction_date, index % 5),
                "pickup_date": date_text(pickup_date, (index + 1) % 5),
                "delivery_date": date_text(delivery_date, (index + 2) % 5) if delivery_date else "",
                "customer_id": random.choice(customers)["customer_id"],
                "origin_branch_id": random.choice(branches)["branch_id"],
                "destination_branch_id": random.choice(branches)["branch_id"],
                "service_code": service_code,
                "courier_id": random.choice(couriers)["courier_id"] if index % 40 != 0 else "",
                "package_id": packages[index - 1]["package_id"],
                "payment_id": payments[index - 1]["payment_id"],
                "status_code": status_code,
                "estimated_days": estimated_days,
                "actual_days": actual_days if actual_days is not None else "",
                "shipping_fee": money_text(shipping_fee, index % 4),
                "insurance_fee": money_text(insurance_fee, (index + 1) % 4),
                "discount_amount": money_text(discount_amount, (index + 2) % 4),
                "total_amount": money_text(total_amount, (index + 3) % 4),
            }
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate PT. LDR dummy CSV source data.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Output folder for CSV files.")
    parser.add_argument("--shipments", type=int, default=10000, help="Total shipment transactions.")
    parser.add_argument("--customers", type=int, default=800, help="Total customers.")
    parser.add_argument("--branches", type=int, default=40, help="Total branches.")
    parser.add_argument("--couriers", type=int, default=250, help="Total couriers.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducible data.")
    args = parser.parse_args()

    if args.shipments < 10000:
        raise ValueError("--shipments must be at least 10000 for this project.")

    output = Path(args.output)
    start_date = date(2025, 1, 1)

    random.seed(args.seed + 1)
    branches = generate_branches(args.branches)
    random.seed(args.seed + 2)
    customers = generate_customers(args.customers)
    random.seed(args.seed + 3)
    couriers = generate_couriers(args.couriers, branches)
    random.seed(args.seed + 4)
    packages = generate_packages(args.shipments)
    random.seed(args.seed + 5)
    payments = generate_payments(args.shipments, start_date)
    random.seed(args.seed + 6)
    shipments = generate_shipments(
        args.shipments,
        customers,
        branches,
        couriers,
        packages,
        payments,
        start_date,
    )

    write_csv(
        output / "customers.csv",
        ["customer_id", "customer_name", "customer_type", "gender", "phone", "email", "city", "province", "registration_date", "status"],
        customers,
    )
    write_csv(
        output / "branches.csv",
        ["branch_id", "branch_name", "branch_type", "address", "city", "province", "region", "manager_name", "opening_date", "is_active"],
        branches,
    )
    write_csv(
        output / "services.csv",
        ["service_code", "service_name", "service_category", "delivery_estimation", "max_weight", "cod_available", "status"],
        [
            {
                "service_code": code,
                "service_name": name,
                "service_category": category,
                "delivery_estimation": estimation,
                "max_weight": max_weight,
                "cod_available": cod,
                "status": status,
            }
            for code, name, category, estimation, max_weight, cod, status, _days in SERVICES
        ],
    )
    write_csv(
        output / "couriers.csv",
        ["courier_id", "courier_name", "gender", "phone", "branch_id", "vehicle_type", "hire_date", "employee_status", "is_active"],
        couriers,
    )
    write_csv(
        output / "packages.csv",
        ["package_id", "package_type", "package_category", "weight", "weight_unit", "length_cm", "width_cm", "height_cm", "fragile_flag", "insured_flag", "item_description"],
        packages,
    )
    write_csv(
        output / "payments.csv",
        ["payment_id", "payment_method", "payment_channel", "bank_name", "payment_date", "payment_status", "is_cod", "refund_status"],
        payments,
    )
    write_csv(
        output / "shipment_status.csv",
        ["status_code", "status_name", "status_category", "status_description"],
        [
            {
                "status_code": code,
                "status_name": name,
                "status_category": category,
                "status_description": description,
            }
            for code, name, category, description in STATUSES
        ],
    )
    write_csv(
        output / "shipments.csv",
        [
            "shipment_id",
            "awb_number",
            "transaction_date",
            "pickup_date",
            "delivery_date",
            "customer_id",
            "origin_branch_id",
            "destination_branch_id",
            "service_code",
            "courier_id",
            "package_id",
            "payment_id",
            "status_code",
            "estimated_days",
            "actual_days",
            "shipping_fee",
            "insurance_fee",
            "discount_amount",
            "total_amount",
        ],
        shipments,
    )

    print(f"Generated {len(shipments)} shipments into {output}")


if __name__ == "__main__":
    main()
