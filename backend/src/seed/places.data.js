'use strict';

/**
 * Areas offered by the manual location picker, each with its approximate
 * centre ([lat, lng]). These are public neighbourhood centroids; whatever a
 * person picks is still blurred by their privacy radius before it is stored.
 * Replace with a places API when one is wired up — the response shape stays.
 */
const PLACES = [
  {
    city: 'Bengaluru', state: 'Karnataka', center: [12.9716, 77.5946],
    areas: {
      'HSR Layout': [12.9116, 77.6389], Koramangala: [12.9352, 77.6245], Indiranagar: [12.9784, 77.6408],
      Whitefield: [12.9698, 77.75], Bellandur: [12.9304, 77.6784], Jayanagar: [12.925, 77.5938],
      Marathahalli: [12.9569, 77.7011], 'Electronic City': [12.8452, 77.6602],
    },
  },
  {
    city: 'Ahmedabad', state: 'Gujarat', center: [23.0225, 72.5714],
    areas: {
      Satellite: [23.03, 72.517], Bodakdev: [23.04, 72.507], 'Prahlad Nagar': [23.012, 72.508],
      'SG Highway': [23.045, 72.51], Maninagar: [22.996, 72.603], Vastrapur: [23.037, 72.529],
      Navrangpura: [23.037, 72.56],
    },
  },
  {
    city: 'Mumbai', state: 'Maharashtra', center: [19.076, 72.8777],
    areas: {
      'Andheri East': [19.1136, 72.8697], 'Bandra Kurla Complex': [19.066, 72.865], Powai: [19.1176, 72.906],
      'Lower Parel': [18.995, 72.83], Thane: [19.2183, 72.9781], 'Navi Mumbai': [19.033, 73.0297],
    },
  },
  {
    city: 'Pune', state: 'Maharashtra', center: [18.5204, 73.8567],
    areas: {
      Hinjewadi: [18.5913, 73.7389], Kharadi: [18.551, 73.935], Baner: [18.559, 73.7868],
      'Viman Nagar': [18.5679, 73.9143], Magarpatta: [18.5146, 73.927],
    },
  },
  {
    city: 'Hyderabad', state: 'Telangana', center: [17.385, 78.4867],
    areas: {
      'HITEC City': [17.4435, 78.3772], Gachibowli: [17.4401, 78.3489], Madhapur: [17.4483, 78.3915],
      Kondapur: [17.46, 78.357], 'Banjara Hills': [17.4156, 78.4347],
    },
  },
  {
    city: 'Delhi', state: 'Delhi', center: [28.6139, 77.209],
    areas: {
      'Connaught Place': [28.6315, 77.2167], Saket: [28.5245, 77.2066], Dwarka: [28.5921, 77.046],
      Rohini: [28.7495, 77.0565], 'Nehru Place': [28.5491, 77.2533],
    },
  },
  {
    city: 'Gurugram', state: 'Haryana', center: [28.4595, 77.0266],
    areas: {
      'Cyber City': [28.495, 77.089], 'Golf Course Road': [28.453, 77.096], 'Udyog Vihar': [28.502, 77.085],
      'Sohna Road': [28.415, 77.043],
    },
  },
  {
    city: 'Noida', state: 'Uttar Pradesh', center: [28.5355, 77.391],
    areas: {
      'Sector 62': [28.627, 77.365], 'Sector 125': [28.544, 77.333], 'Sector 16': [28.579, 77.315],
      'Greater Noida': [28.4744, 77.504],
    },
  },
  {
    city: 'Chennai', state: 'Tamil Nadu', center: [13.0827, 80.2707],
    areas: {
      OMR: [12.901, 80.2279], Guindy: [13.0067, 80.2206], 'T Nagar': [13.0418, 80.2341],
      Velachery: [12.9815, 80.218], Ambattur: [13.1143, 80.1548],
    },
  },
  {
    city: 'Kolkata', state: 'West Bengal', center: [22.5726, 88.3639],
    areas: {
      'Salt Lake Sector V': [22.576, 88.433], 'New Town': [22.592, 88.484], 'Park Street': [22.553, 88.352],
      Howrah: [22.5958, 88.2636],
    },
  },
  {
    city: 'Jaipur', state: 'Rajasthan', center: [26.9124, 75.7873],
    areas: {
      'Malviya Nagar': [26.853, 75.805], 'Vaishali Nagar': [26.912, 75.743], 'C Scheme': [26.908, 75.8],
      Mansarovar: [26.87, 75.76],
    },
  },
  {
    city: 'Indore', state: 'Madhya Pradesh', center: [22.7196, 75.8577],
    areas: {
      'Vijay Nagar': [22.753, 75.893], Palasia: [22.724, 75.884], Rau: [22.637, 75.813],
      'Scheme 78': [22.756, 75.896],
    },
  },
  {
    city: 'Surat', state: 'Gujarat', center: [21.1702, 72.8311],
    areas: { Adajan: [21.195, 72.793], Vesu: [21.142, 72.771], Piplod: [21.159, 72.774], Katargam: [21.229, 72.833] },
  },
  {
    city: 'Kochi', state: 'Kerala', center: [9.9312, 76.2673],
    areas: {
      Infopark: [10.01, 76.363], Kakkanad: [10.0159, 76.3419], Edappally: [10.0261, 76.3083],
      'Fort Kochi': [9.9658, 76.2421],
    },
  },
  {
    city: 'Chandigarh', state: 'Chandigarh', center: [30.7333, 76.7794],
    areas: {
      'IT Park': [30.727, 76.846], 'Sector 17': [30.741, 76.782], Mohali: [30.7046, 76.7179],
      Panchkula: [30.6942, 76.8606],
    },
  },
];

/** Looks up a known area (or city) and returns its centre, or null. */
function findPlace(areaName, cityName) {
  const city = PLACES.find((entry) => entry.city.toLowerCase() === String(cityName || '').toLowerCase());
  if (!city) return null;
  const areaKey = Object.keys(city.areas).find(
    (key) => key.toLowerCase() === String(areaName || '').toLowerCase()
  );
  const [latitude, longitude] = areaKey ? city.areas[areaKey] : city.center;
  return { area: areaKey || '', city: city.city, state: city.state, latitude, longitude };
}

module.exports = { PLACES, findPlace };
