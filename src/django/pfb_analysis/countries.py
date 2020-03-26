from django.conf import settings
import pycountry


def get_country_config(alpha_2):
    return settings.COUNTRY_CONFIG.get(alpha_2, settings.COUNTRY_CONFIG['default'])


def use_subdivisions(alpha_2):
    return get_country_config(alpha_2)['use_subdivisions']


def require_subdivisions(alpha_2):
    return use_subdivisions(alpha_2) and get_country_config(alpha_2)['subdivisions_required']


def subdivisions_for_country(alpha_2):
    """ Subdivisions for the given country, if we want to track them

    Returns a list of subdivisions, as {name, code, type}, for the given country, but
    only if the country config in settings says to track subdivisions for the country. Otherwise
    returns None.
    """
    if not use_subdivisions(alpha_2):
        return None

    # If they're hand-coded because 'pycountry' doesn't have what we need, use them
    if 'subdivisions' in get_country_config(alpha_2):
        return get_country_config(alpha_2)['subdivisions']

    # If not, extract them from 'pycountry'
    # Note: pycountry's subdivision codes all start with the alpha_2 country code and
    # a hyphen. Since we're attaching them to the country and don't expect to be
    # mingling subdivisions from different countries, this strips off the prefix and
    # keeps only the actual subdivision code.
    subdivisions = [{'name': s.name, 'code': s.code[3:], 'type': s.type} for s in
                    pycountry.subdivisions.get(country_code=alpha_2)]

    # If there's a whitelist of desired types, filter to that (otherwise use all types)
    types = get_country_config(alpha_2).get('subdivision_types')
    if types is not None:
        subdivisions = [s for s in subdivisions if s['type'] in types]

    subdivisions.sort(key=lambda s: s['name'])
    return subdivisions


def build_country_list():
    """ Build a list of countries, without US territories and with subdivisions if desired

    Builds a list of {alpha_2, name, subdivisions} dictionaries, where 'subdivisions' is
    a dictionary of {code, name, type} subdivisions, but is only present if the country
    config in settings calls for tracking subdivisions for the country.

    US territories are present in both the countries and subdivisions lists in pycountry,
    so we need to get a list of them and filter them out of the countries list.
    """
    us_territories = [t['code'] for t in subdivisions_for_country('US')
                      if t['type'] == 'Outlying area']
    countries = []
    for country in pycountry.countries:
        if country.alpha_2 in us_territories:
            continue
        country_dict = {'alpha_2': country.alpha_2, 'name': country.name}
        subdivisions = subdivisions_for_country(country.alpha_2)
        if subdivisions is not None:
            country_dict['subdivisions'] = subdivisions
            country_dict['subdivisions_required'] = require_subdivisions(country.alpha_2)
        countries.append(country_dict)
    countries.sort(key=lambda c: c['name'])
    return countries
