import csv
import os
import json


def filter_csv_and_convert_to_dict():
    # Get the directory path of the current script
    script_directory = os.path.dirname(os.path.abspath(__file__))

    # Construct the full path to the CSV file located in the same directory
    # Replace 'your_file_name.csv' with the actual filename
    file_path = os.path.join(script_directory, 'mac_24bit.csv')

    with open(file_path, 'r') as csvfile:
        csvreader = csv.reader(csvfile)
        result_dict = {}

        for row in csvreader:
            try:
                if len(row) == 4:
                    _, mac, vendor, _ = row

                    result_dict[mac] = vendor
            except Exception as e:
                print(e)
                break

    return result_dict


def save_to_json(data, output_file="mac_24bit.json"):
    # Get the directory path of the current script
    script_directory = os.path.dirname(os.path.abspath(__file__))

    # Construct the full path to the output JSON file located in the same directory
    output_path = os.path.join(script_directory, output_file)

    with open(output_path, 'w') as jsonfile:
        json.dump(data, jsonfile, indent=4)


if __name__ == "__main__":
    filtered_data = filter_csv_and_convert_to_dict()

    # Save the filtered data to a JSON file named 'output.json'
    save_to_json(filtered_data)

    print("Data saved to output.json.")
