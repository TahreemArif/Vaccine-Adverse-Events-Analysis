import os
import re
import math
import time
import pandas as pd
import google.generativeai as genai
from sqlalchemy import create_engine

from dotenv import load_dotenv

# Load variables from .env file
load_dotenv('config.env')

api_key = os.getenv("GEMINI_API_KEY")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_pswd = os.getenv("DB_PSWD")

# Example batch usage
batch_size = 500
total_records = 343375
num_batches = math.ceil(total_records / batch_size)

# Define your SQLAlchemy connection parameters for `to_sql`
conn_str = f"postgresql+psycopg2://{db_user}:{db_pswd}@{db_host}:{db_port}/{db_name}"
engine = create_engine(conn_str)


def load_batch(limit, offset, conn):
    query = f"""
        SELECT *
        FROM vaers_data
        WHERE json_array_length(symptom_list) > 1
        ORDER BY vaers_id
        LIMIT {limit}
        OFFSET {offset}
    """
    return pd.read_sql(query, con=conn)


def create_prompt(symptom_text, ground_truth_symptoms):
    return f"""
    Order the symptoms according to the timeline implied in the text.
    
    Text: "Patient reported that she noticed a diffuse rash on 1/25/2021. The rash was located on her wrists down to her fingers, both upper thighs, on her right arm and elbow. She described the rash as "raised bumps that are chickenpox-ish but not dark red dots". She also said that they look like, "hives with the welts and the white-ish area around that focal part of the rash". She said it is not painful. She said the rash is mostly not itchy, except for her right elbow which is very itchy.  She added that on the day of vaccination, 1/14/2021 (she received the vaccine around 2:30pm), she noticed some intestinal cramping between 6:30 and 7:30pm. She had no nausea or vomiting. She stated she did have two or three episodes of loose stool, but not outright diarrhea. She said she had no GI symptoms beyond 1/14/2021."
    Symptoms: [Rash, Diarrhoea, Gastrointestinal pain]
    Ordered Symptoms: [Diarrhoea, Gastrointestinal pain, Rash]

    Text: "Fever, body aches and chills began Tuesday, 1/26/21 @ 1:10am. 
           Took Tylenol, but fever and chills did not go away completely. 
           Right arm continues to be extremely sore even after taking Tylenol"
           
    Symptoms: [Chills, Pain, Pain in extremity, Pyrexia]
    
    Ordered Symptoms: [Pyrexia, Chills, Pain, Pain in extremity]
    
    Text: "Given Tdap injection on 1/21/11 and several days later noticed redness and swelling."
    Symptoms: [swelling, redness]
    Ordered Symptoms: [redness, swelling]
    
    Text: "anxiety, itching  administered 25mg liquid Benadryl orally, patient left in stable condition."
    Symptoms: [Anxiety, Pruritus]
    Ordered Symptoms: [Anxiety, Pruritus] 
    
    Text: "{symptom_text}"
    Symptoms: {ground_truth_symptoms}
    Ordered Symptoms:
    """


def extract_symptoms(text):
    # Regex to find the list inside "Ordered Symptoms: [...]"
    match = re.search(r"(\*\*)?Ordered Symptoms:(\*\*)?\s*\[([^\]]+)\]", text)

    if match:
        # Capture the contents within the square brackets
        symptoms_text = match.group(3)
        # Split the symptoms by comma and strip any extra whitespace
        symptoms_list = [symptom.strip(" '\"") for symptom in symptoms_text.split(",")]
        return symptoms_list
    return []


def save_batch_to_db(df, conn, table_name="vaers_processed_data"):
    # Save each batch to the database
    try:
        df.to_sql(table_name, con=conn, if_exists="append", index=False)
    except Exception as e:
        print(f"Error saving data to database: {e}")


if __name__ == '__main__':
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")
    errors = {}

    # Annotate each record independently
    try:
        for i in range(num_batches):
            vaers_data = load_batch(batch_size, offset=i*batch_size, conn=engine)
            print(f'Loaded dataset, with limit {batch_size}, offset: {i*batch_size}')

            results = []
            for _, row in vaers_data.iterrows():
                response = None
                prompt = create_prompt(row['symptom_text'], row['symptom_list'])
                try:
                    response = model.generate_content(prompt)
                    ordered_symptoms = response.text

                except Exception as e:
                    print(f"Error processing request: {e}\n\n Prompt:  {prompt}")
                    if response:
                        errors[row['vaers_id']] = response._result
                    ordered_symptoms = 'Ordered Symptoms: [] \n'

                results.append(ordered_symptoms)
            vaers_data['ordered_symptoms_gemini_1.5'] = results

            # Apply the function to the DataFrame
            vaers_data['ordered_symptoms'] = vaers_data['ordered_symptoms_gemini_1.5'].apply(extract_symptoms)

            # Save the processed batch to the database
            save_batch_to_db(vaers_data, conn=engine)
            print(f"Batch {i + 1}/{num_batches} processed and saved.")
            time.sleep(10)

    except Exception as e:
        print(f"Error processing batch {i + 1}: {e}")

    errors_df = pd.DataFrame(list(errors.items()), columns=['vaers_id', 'error_response'])
    save_batch_to_db(errors_df, conn=engine, table_name='error_logs')

    engine.dispose()
